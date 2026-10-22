// Feeds herdr's Agents sidebar with what omp is actually doing. $agent is the
// active model: omp has no named primary agents.
//
// Managed by nix (modules/programs/herdr/omp-activity.ts). It publishes
// display-only pane metadata through `pane.report_metadata` and never calls
// `pane.report_agent`, so it cannot disturb the lifecycle state or the session
// identity owned by herdr's own integration next to it.
//
// Tokens: $agent $title $todo $sub1..$sub3 $submore

import net from "node:net";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const SOURCE = "user:omp-activity";
const SUB_SLOTS = 3;
const MAX_VALUE = 72;
const TTL_MS = 12 * 60 * 60 * 1000;

const paneId = process.env.HERDR_PANE_ID;
const socketPath = process.env.HERDR_SOCKET_PATH;
// omp sets OMPCODE=1 in every shell it spawns, so an omp started from a
// session's shell is nested and must not overwrite the pane's tokens.
const enabled =
  process.env.HERDR_ENV === "1" &&
  !!paneId &&
  !!socketPath &&
  process.env.OMPCODE !== "1";

let reportSeq = Date.now() * 1000;
let requestChain: Promise<void> = Promise.resolve();

const state = { agent: "", title: "", todo: "" };
let agentActive = false;
// Keyed by subagent id. Workers are tracked by their own lifecycle, not by the
// `task` call: a background spawn returns at once while its workers run on.
const subagents = new Map<string, { type: string; description: string }>();

function clean(value: unknown): string {
  const text = String(value ?? "")
    .replace(/\s+/g, " ")
    .trim();

  return text.length <= MAX_VALUE ? text : `${text.slice(0, MAX_VALUE - 1)}…`;
}

function requestOnce(
  method: string,
  params: Record<string, unknown>,
): Promise<void> {
  reportSeq = Math.max(reportSeq + 1, Date.now() * 1000);
  const request = {
    id: `${SOURCE}:${Date.now()}:${Math.floor(Math.random() * 1_000_000)
      .toString()
      .padStart(6, "0")}`,
    method,
    params: { pane_id: paneId, source: SOURCE, seq: reportSeq, ...params },
  };

  return new Promise((resolve) => {
    const client = net.createConnection(socketPath!, () => {
      client.write(`${JSON.stringify(request)}\n`);
    });
    const finish = () => {
      client.destroy();
      resolve();
    };
    client.setTimeout(500, finish);
    client.on("data", finish);
    client.on("error", finish);
    client.on("end", finish);
    client.on("close", () => resolve());
  });
}

function publish(): Promise<void> {
  const tokens: Record<string, string> = {
    agent: agentActive ? state.agent : "",
    title: state.title,
    todo: state.todo,
  };

  const running = [...subagents.values()];
  for (let slot = 0; slot < SUB_SLOTS; slot += 1) {
    const entry = running[slot];
    tokens[`sub${slot + 1}`] = entry
      ? clean(
          entry.description
            ? `${entry.type}: ${entry.description}`
            : entry.type,
        )
      : "";
  }
  tokens.submore = clean(
    running
      .slice(SUB_SLOTS)
      .map((entry) => entry.type)
      .join(", "),
  );

  const pending = requestChain.then(() =>
    requestOnce("pane.report_metadata", { tokens, ttl_ms: TTL_MS }),
  );
  requestChain = pending.catch(() => {});
  return pending;
}

type TodoTask = { content?: string; status?: string };

function todoSummary(phases: unknown): string {
  if (!Array.isArray(phases)) {
    return "";
  }
  const tasks: TodoTask[] = phases.flatMap((phase) =>
    Array.isArray(phase?.tasks) ? phase.tasks : [],
  );
  if (!tasks.length) {
    return "";
  }
  const active = tasks.find((task) => task.status === "in_progress");
  const done = tasks.filter((task) => task.status === "completed").length;
  if (done === tasks.length) return "";
  return clean(`${done}/${tasks.length} ${active?.content ?? ""}`);
}

// The latest todo snapshot on the active branch, by the same rules as omp's
// own canonicalTodoPhases (tools/todo.ts): a successful, non-view todo result.
function todoFromBranch(ctx: any): string {
  let entries: any[] = [];
  try {
    entries = ctx?.sessionManager?.getBranch?.() ?? [];
  } catch {
    return "";
  }
  for (let i = entries.length - 1; i >= 0; i -= 1) {
    const message =
      entries[i]?.type === "message" ? entries[i].message : undefined;
    if (
      message?.role === "toolResult" &&
      message.toolName === "todo" &&
      !message.isError &&
      message.details?.op !== "view" &&
      Array.isArray(message.details?.phases)
    ) {
      return todoSummary(message.details.phases);
    }
  }
  return "";
}

export default function (pi: ExtensionAPI) {
  if (!enabled) {
    return;
  }

  // Subagent sessions rebind every extension, and their events must not
  // reach the pane's tokens. Same test as herdr's own omp integration.
  const isRoot = (ctx: any) =>
    ctx?.hasUI === true && ctx?.agent?.kind !== "sub";

  let unsubscribeTitle: (() => void) | undefined;

  // A new, resumed or re-branched session must not inherit the previous
  // one's tokens, and a fresh process has seen none of its todo results.
  const reseed = async (ctx: any) => {
    unsubscribeTitle?.();
    // Automatic titles and /rename can finish between agent lifecycle events.
    unsubscribeTitle = ctx.sessionManager.onSessionNameChanged(() => {
      state.title = clean(pi.getSessionName() ?? "");
      void publish();
    });
    state.title = clean(pi.getSessionName() ?? "");
    state.todo = todoFromBranch(ctx);
    subagents.clear();
    agentActive = ctx?.isIdle?.() === false;
    await publish();
  };

  for (const event of [
    "session_start",
    "session_switch",
    "session_branch",
    "session_tree",
  ] as const) {
    pi.on(event, async (_event: unknown, ctx: any) => {
      if (isRoot(ctx)) await reseed(ctx);
    });
  }

  // herdr keys metadata by pane and source, not by process: without an explicit
  // clear the last tokens outlive omp until their TTL, under whatever runs next.
  pi.on("session_shutdown", async (_event, ctx) => {
    if (!isRoot(ctx)) return;
    unsubscribeTitle?.();
    unsubscribeTitle = undefined;
    state.agent = "";
    state.title = "";
    state.todo = "";
    subagents.clear();
    agentActive = false;
    await publish();
  });

  pi.on("agent_start", async (_event, ctx) => {
    if (!isRoot(ctx)) return;
    state.agent = clean(ctx.model?.id ?? "");
    state.title = clean(pi.getSessionName() ?? "");
    agentActive = true;
    await publish();
  });

  pi.on("agent_end", async (event: any, ctx) => {
    if (!isRoot(ctx) || event?.willContinue === true) return;
    agentActive = false;
    state.title = clean(pi.getSessionName() ?? "");
    await publish();
  });

  pi.on("tool_result", async (event: any, ctx) => {
    if (
      !isRoot(ctx) ||
      event.toolName !== "todo" ||
      event.isError ||
      event.details?.op === "view"
    )
      return;
    state.todo = todoSummary(event.details?.phases);
    await publish();
  });

  // Emitted on the session's own bus, so only this session's workers arrive.
  pi.events.on("task:subagent:lifecycle", (data: any) => {
    if (typeof data?.id !== "string") return;
    if (data.status === "started") {
      subagents.set(data.id, {
        type: clean(data.agent ?? "task"),
        description: clean(data.description ?? ""),
      });
    } else if (!subagents.delete(data.id)) {
      return;
    }
    void publish();
  });
}

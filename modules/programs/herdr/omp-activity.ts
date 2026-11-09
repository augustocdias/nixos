// Feeds Herdr App's Agents sidebar. OMP has no named primary agents, so the
// agent field contains its selected model.
//
// Managed by nix (modules/programs/herdr/omp-activity.ts). Reports use the
// launcher's display-only Core bridge, separate from native lifecycle status.
//
// Metadata: agent, title, todo, sub1..sub3, submore, plus optional details for
// expanded cards (limits in modules/programs/agent-jail/_herdr-relay/server.py).

import fs from "node:fs";
import net from "node:net";
import path from "node:path";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const SOURCE = "user:omp-activity";
const SUB_SLOTS = 3;
const MAX_VALUE = 72;

const socketPath = process.env.HERDR_ACTIVITY_SOCKET;
// omp sets OMPCODE=1 in every shell it spawns, so an omp started from a
// session's shell is nested and must not overwrite the pane's tokens.
const enabled = !!socketPath && process.env.OMPCODE !== "1";

let reportSeq = Date.now() * 1000;
let requestChain: Promise<void> = Promise.resolve();
let epoch = 0;
let session = "";
let rootActive = false;

type TodoTask = { content?: string; status?: string };

const state = { model: "", title: "", cwd: "", tasks: [] as TodoTask[] };
// Keyed by subagent id. Workers are tracked by their own lifecycle, not by the
// `task` call: a background spawn returns at once while its workers run on.
const subagents = new Map<string, { type: string; description: string }>();

function clean(value: unknown, limit = MAX_VALUE): string {
  // The relay rejects control characters; whitespace ones become spaces.
  const text = String(value ?? "")
    .replace(/\s+/g, " ")
    .replace(/\p{Cc}/gu, "")
    .trim();
  if (text.length <= limit) return text;
  // Cut whole code points: a lone surrogate is invalid JSON to the relay. The
  // UTF-16 bounds keep legacy tokens within the navigation mods' .length check.
  let cut = "";
  for (const char of text) {
    if (cut.length + char.length > limit - 1) break;
    cut += char;
  }
  return `${cut}…`;
}

// Branch name, or the short commit when detached.
function gitBranch(cwd: string): string {
  try {
    let dir = path.resolve(cwd);
    while (!fs.existsSync(path.join(dir, ".git"))) {
      if (path.dirname(dir) === dir) return "";
      dir = path.dirname(dir);
    }
    let git = path.join(dir, ".git");
    if (fs.statSync(git).isFile()) {
      const line = fs.readFileSync(git, "utf8").slice(0, 4096).trim();
      if (!line.startsWith("gitdir:")) return "";
      git = path.resolve(dir, line.slice("gitdir:".length).trim());
    }
    const head = fs.readFileSync(path.join(git, "HEAD"), "utf8").slice(0, 4096).trim();
    return head.startsWith("ref: refs/heads/") ? head.slice("ref: refs/heads/".length) : head.slice(0, 12);
  } catch {
    return "";
  }
}

function todoToken(tasks: TodoTask[]): string {
  const done = tasks.filter((task) => task.status === "completed").length;
  if (done === tasks.length) return "";
  const active = tasks.find((task) => task.status === "in_progress");
  return clean(`${done}/${tasks.length} ${active?.content ?? ""}`);
}

// Longer, structured view of the same session for expanded cards.
function details(): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const [key, value, limit] of [
    ["model", state.model, 128],
    ["title", state.title, 300],
    ["workspace", state.cwd, 512],
    ["branch", state.cwd ? gitBranch(state.cwd) : "", 200],
  ] as const) {
    const text = clean(value, limit);
    if (text) result[key] = text;
  }
  if (state.tasks.length) {
    result.tasks = {
      completed: Math.min(state.tasks.filter((task) => task.status === "completed").length, 10_000),
      total: Math.min(state.tasks.length, 10_000),
      active: state.tasks
        .filter((task) => task.status === "in_progress")
        .map((task) => clean(task.content, 200))
        .filter(Boolean)
        .slice(0, 5),
    };
  }
  if (subagents.size) {
    const items: Record<string, string>[] = [];
    for (const [rawId, entry] of subagents) {
      const id = clean(rawId, 128) || "task";
      // IDs that collide after bounding are omitted; total still counts them.
      if (items.some((item) => item.id === id)) continue;
      items.push({ id, type: entry.type || "task", description: entry.description });
      if (items.length === 8) break;
    }
    result.subagents = { total: Math.min(subagents.size, 10_000), items };
  }
  return result;
}

function requestOnce(
  params: Record<string, unknown>,
): Promise<void> {
  reportSeq = Math.max(reportSeq + 1, Date.now() * 1000);
  const request = {
    id: `${SOURCE}:${reportSeq}`,
    method: "activity.report",
    params: { seq: reportSeq, ...params },
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
    agent: clean(state.model),
    title: clean(state.title),
    todo: todoToken(state.tasks),
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

  // Snapshot every field now; queued sends must not read later state.
  const params = { tokens, details: details(), epoch, session };
  const pending = requestChain.then(() => requestOnce(params));
  requestChain = pending.catch(() => {});
  return pending;
}

function todoTasks(phases: unknown): TodoTask[] {
  if (!Array.isArray(phases)) {
    return [];
  }
  return phases
    .flatMap((phase) => (Array.isArray(phase?.tasks) ? phase.tasks : []))
    .filter((task) => task && typeof task === "object");
}

// The latest todo snapshot on the active branch, by the same rules as omp's
// own canonicalTodoPhases (tools/todo.ts): a successful, non-view todo result.
function todoFromBranch(ctx: any): TodoTask[] {
  let entries: any[] = [];
  try {
    entries = ctx?.sessionManager?.getBranch?.() ?? [];
  } catch {
    return [];
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
      return todoTasks(message.details.phases);
    }
  }
  return [];
}

export default function (pi: ExtensionAPI) {
  if (!enabled) {
    return;
  }

  // Subagent sessions rebind every extension, and their events must not
  // reach the root terminal's tokens.
  const isRoot = (ctx: any) =>
    ctx?.hasUI === true && ctx?.agent?.kind !== "sub";

  let unsubscribeTitle: (() => void) | undefined;
  let heartbeat: NodeJS.Timeout | undefined;

  // A new, resumed or re-branched session must not inherit the previous
  // one's tokens, and a fresh process has seen none of its todo results.
  const reseed = async (ctx: any) => {
    unsubscribeTitle?.();
    rootActive = true;
    epoch = Math.max(epoch + 1, Date.now() * 1000);
    session = ctx.sessionManager.getSessionId();
    state.model = ctx.model?.id ?? "";
    state.cwd = typeof ctx.cwd === "string" ? ctx.cwd : "";
    if (!heartbeat) {
      heartbeat = setInterval(() => { void publish(); }, 30_000);
      heartbeat.unref();
    }
    // Automatic titles and /rename can finish between agent lifecycle events.
    unsubscribeTitle = ctx.sessionManager.onSessionNameChanged(() => {
      state.title = pi.getSessionName() ?? "";
      void publish();
    });
    state.title = pi.getSessionName() ?? "";
    state.tasks = todoFromBranch(ctx);
    subagents.clear();
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

  // Clear display metadata before another program takes over the terminal.
  pi.on("session_shutdown", async (_event, ctx) => {
    if (!isRoot(ctx)) return;
    rootActive = false;
    clearInterval(heartbeat);
    heartbeat = undefined;
    unsubscribeTitle?.();
    unsubscribeTitle = undefined;
    state.model = "";
    state.title = "";
    state.cwd = "";
    state.tasks = [];
    subagents.clear();
    await publish();
  });

  pi.on("agent_start", async (_event, ctx) => {
    if (!isRoot(ctx)) return;
    state.model = ctx.model?.id ?? "";
    state.title = pi.getSessionName() ?? "";
    await publish();
  });

  pi.on("agent_end", async (event: any, ctx) => {
    if (!isRoot(ctx) || event?.willContinue === true) return;
    state.title = pi.getSessionName() ?? "";
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
    state.tasks = todoTasks(event.details?.phases);
    await publish();
  });

  // Emitted on the session's own bus, so only this session's workers arrive.
  pi.events.on("task:subagent:lifecycle", (data: any) => {
    if (!rootActive) return;
    if (typeof data?.id !== "string") return;
    if (data.status === "started") {
      subagents.set(data.id, {
        type: clean(data.agent ?? "task", 64),
        description: clean(data.description ?? "", 200),
      });
    } else if (!subagents.delete(data.id)) {
      return;
    }
    void publish();
  });

  // `task` spawns carry no description at start: omp generates the title
  // afterwards and only publishes it on progress frames.
  pi.events.on("task:subagent:progress", (data: any) => {
    if (!rootActive) return;
    const id = data?.progress?.id;
    const entry = typeof id === "string" ? subagents.get(id) : undefined;
    const description = clean(data?.progress?.description ?? "", 200);
    if (!entry || !description || description === entry.description) return;
    entry.description = description;
    void publish();
  });
}

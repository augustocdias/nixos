// Feeds herdr's Agents sidebar with what OpenCode is actually doing.
//
// Managed by nix (modules/programs/herdr/opencode-activity.js). It publishes
// display-only pane metadata through `pane.report_metadata` and never calls
// `pane.report_agent`, so it cannot disturb the lifecycle state or the session
// identity owned by herdr's own integration next to it.
//
// Tokens: $agent $title $todo $sub1..$sub3 $submore

import net from "node:net";

const SOURCE = "user:opencode-activity";
const SUB_SLOTS = 3;
const MAX_VALUE = 72;
const TTL_MS = 12 * 60 * 60 * 1000;

const DEFAULT_TITLE =
  /^(New session - |Child session - )\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/;

let reportSeq = Date.now() * 1000;
let requestChain = Promise.resolve();

const childSessions = new Set();
// The pane's own session. Subagents get their own sessions and their own idle
// events, so the id is needed to tell whose idle just arrived.
let rootSessionID;

const state = { agent: "", title: "", todo: "" };
// `agent` is remembered but only published while the session is active: the
// value stays correct across a turn even if idle arrives between steps.
let agentActive = false;
const subagents = new Map();

function nextReportSeq() {
  reportSeq += 1;
  return reportSeq;
}

function clean(value) {
  const text = String(value ?? "")
    .replace(/\s+/g, " ")
    .trim();
  if (text.length <= MAX_VALUE) {
    return text;
  }
  return `${text.slice(0, MAX_VALUE - 1)}…`;
}

function request(method, params) {
  const pending = requestChain.then(() => requestOnce(method, params));
  requestChain = pending.catch(() => {});
  return pending;
}

function requestOnce(method, params) {
  const paneId = process.env.HERDR_PANE_ID;
  const socketPath = process.env.HERDR_SOCKET_PATH;

  if (!paneId || !socketPath) {
    return Promise.resolve();
  }

  const socketEndpoint =
    process.platform === "win32" ? `\\\\.\\pipe\\${socketPath}` : socketPath;

  const request = {
    id: `${SOURCE}:${Date.now()}:${Math.floor(Math.random() * 1_000_000)
      .toString()
      .padStart(6, "0")}`,
    method,
    params: {
      pane_id: paneId,
      source: SOURCE,
      seq: nextReportSeq(),
      ...params,
    },
  };

  return new Promise((resolve) => {
    const client = net.createConnection(socketEndpoint, () => {
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
    client.on("close", resolve);
  });
}

function publish() {
  const tokens = {
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

  return request("pane.report_metadata", { tokens, ttl_ms: TTL_MS });
}

function sessionIDFromProperties(properties) {
  return typeof properties?.sessionID === "string" && properties.sessionID
    ? properties.sessionID
    : undefined;
}

// Anything that is not this pane's own session: a known subagent, or any other
// session once the pane's own id is known.
function foreignSession(sessionID) {
  if (!sessionID) {
    return false;
  }
  if (childSessions.has(sessionID)) {
    return true;
  }
  return rootSessionID ? sessionID !== rootSessionID : false;
}

async function markAgentActive() {
  if (state.agent && !agentActive) {
    agentActive = true;
    await publish();
  }
}

// A resumed session emits no session.updated, so the title and todo list have
// to be fetched once instead of waited for.
const seeded = new Set();

async function seedFromSession(client, sessionID) {
  if (!sessionID || seeded.has(sessionID) || !client?.session) {
    return;
  }
  seeded.add(sessionID);

  if (!state.title) {
    try {
      const title = (await client.session.get({ sessionID }))?.data?.title;
      if (typeof title === "string" && title && !DEFAULT_TITLE.test(title)) {
        state.title = clean(title);
        await publish();
      }
    } catch {
      // A missing or renamed endpoint must not break the reporting below.
    }
  }

  if (!state.todo) {
    try {
      const todos = (await client.session.todo({ sessionID }))?.data;
      if (Array.isArray(todos) && todos.length) {
        state.todo = clean(todoSummary(todos));
        await publish();
      }
    } catch {}
  }
}

function todoSummary(todos) {
  const active = todos.find((todo) => todo.status === "in_progress");
  const done = todos.filter((todo) => todo.status === "completed").length;
  return `${done}/${todos.length} ${active?.content ?? ""}`;
}

export const HerdrActivityPlugin = async ({ client } = {}) => {
  if (
    process.env.HERDR_ENV !== "1" ||
    !process.env.HERDR_SOCKET_PATH ||
    !process.env.HERDR_PANE_ID
  ) {
    return {};
  }

  return {
    "chat.message": async ({ sessionID, agent }) => {
      if (foreignSession(sessionID)) {
        return;
      }
      if (sessionID && !rootSessionID) {
        rootSessionID = sessionID;
      }
      const next = agent ? clean(agent) : state.agent;
      if (next !== state.agent || !agentActive) {
        state.agent = next;
        agentActive = true;
        await publish();
      }
      await seedFromSession(client, sessionID);
    },

    "tool.execute.before": async ({ tool, sessionID, callID }, output) => {
      if (foreignSession(sessionID)) {
        return;
      }
      if (tool !== "task") {
        // Any tool call means the turn is still running, so re-show the agent
        // if an idle event hid it mid-turn.
        await markAgentActive();
        return;
      }
      const args = output?.args ?? {};
      subagents.set(callID, {
        type: clean(args.subagent_type ?? "subagent"),
        description: clean(args.description ?? ""),
      });
      agentActive = state.agent ? true : agentActive;
      await publish();
    },

    "tool.execute.after": async ({ tool, sessionID, callID }) => {
      if (foreignSession(sessionID)) {
        return;
      }
      if (tool === "task" && subagents.delete(callID)) {
        await publish();
        return;
      }
      await markAgentActive();
    },

    event: async ({ event }) => {
      const type = event?.type;
      const properties = event?.properties ?? {};
      const info = properties.info;

      if (info?.id && info.parentID) {
        childSessions.add(info.id);
      }
      if (info?.id && !info.parentID && !rootSessionID) {
        rootSessionID = info.id;
      }

      const sessionID = sessionIDFromProperties(properties);
      if (foreignSession(sessionID)) {
        return;
      }
      if (sessionID) {
        await seedFromSession(client, sessionID);
      }

      switch (type) {
        case "session.created":
        case "session.updated": {
          if (!info?.id || info.parentID) {
            return;
          }
          const title =
            typeof info.title === "string" && !DEFAULT_TITLE.test(info.title)
              ? info.title
              : "";
          if (clean(title) !== state.title) {
            state.title = clean(title);
            await publish();
          }
          break;
        }

        case "todo.updated": {
          const todos = Array.isArray(properties.todos) ? properties.todos : [];
          state.todo = todos.length ? clean(todoSummary(todos)) : "";
          await publish();
          break;
        }

        case "session.status": {
          const kind =
            typeof properties.status === "string"
              ? properties.status
              : properties.status?.type;
          if (kind && kind !== "idle") {
            await markAgentActive();
          }
          break;
        }

        case "session.idle": {
          if (rootSessionID && sessionID !== rootSessionID) {
            break;
          }
          if (agentActive) {
            agentActive = false;
            await publish();
          }
          break;
        }

        default:
          break;
      }
    },
  };
};

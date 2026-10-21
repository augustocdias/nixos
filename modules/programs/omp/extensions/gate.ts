// Approval for the work MCP servers.
//
// omp keys `tools.approval` by exact tool name with no wildcards, and these
// servers add tools upstream at will, so an exact list would silently allow
// every new write. Here reads pass and anything else asks. No UI (subagents,
// rpc --no-ui) means blocked, never allowed.
//
// Managed by nix (modules/programs/omp/extensions/gate.ts).

import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const GATED = new Set(["notion", "linear", "datadog"]);

// Nouns that precede the verb in some tool names: `calendar_list_events`,
// and datadog's tools repeat their own server name.
const NOUNS = new Set(["notion", "calendar", "datadog"]);
const READ_VERBS = new Set([
  "get",
  "list",
  "search",
  "fetch",
  "query",
  "aggregate",
  "analyze",
]);

// omp registers MCP tools as `mcp__<server>_<tool>`, lowercased.
const MCP_NAME = /^mcp__([a-z0-9]+)_(.+)$/;

function isRead(tool: string): boolean {
  const verb = tool.split("_").find((segment) => !NOUNS.has(segment));
  return verb !== undefined && READ_VERBS.has(verb);
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    const match = MCP_NAME.exec(event.toolName);
    if (!match || !GATED.has(match[1]) || isRead(match[2])) {
      return;
    }
    if (!ctx.hasUI) {
      return {
        block: true,
        reason: `${event.toolName} needs approval and no UI is available`,
      };
    }

    // herdr's omp integration listens on this channel, so the pane shows as
    // blocked while the dialog waits.
    pi.events.emit("herdr:blocked", {
      active: true,
      label: `${event.toolName} approval`,
    });
    try {
      const approved = await ctx.ui.confirm(
        `Allow ${event.toolName}?`,
        JSON.stringify(event.input, null, 2).slice(0, 2000),
      );
      if (!approved) {
        return { block: true, reason: "Denied by the user" };
      }
    } finally {
      pi.events.emit("herdr:blocked", { active: false });
    }
  });
}

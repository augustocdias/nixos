// Report tools for omp agents launched from a Hermes template, loaded with
// `omp -e` because omp has no per-run MCP flag. Mirrors mcp.py's report mode.
//
// Managed by nix (modules/services/hermes-agent/report.ts). @url@ is the
// Hermes plugin's loopback endpoint.

import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const URL = "@url@";

const TOOLS = [
  ["report_done", "result", "Final action for a fully completed assignment. Before calling, collect all subagent results, resolve findings, finish required checks and assigned actions, and stop owned temporary processes. Nothing may remain running or pending. Use comment for subtask/follow-up progress, ask for decisions, or report_blocked for unmet requirements. Never batch with another call. After success, end the turn immediately with no further tools or work until a new explicit assignment. Reports completion of this stage, not the whole card."],
  ["report_blocked", "reason", "Report that you cannot go on without help, with the reason."],
  ["ask", "question", "Ask Hermes a question and end your turn. Your role answers from existing context or blocks the card for coordinator review. Wait for a follow-up message, not terminal input from the user."],
  ["comment", "text", "Add a progress note to the card. Call it first thing, then whenever useful."],
] as const;

export default function (pi: ExtensionAPI) {
  const z = pi.zod;
  for (const [name, field, description] of TOOLS) {
    pi.registerTool({
      name,
      label: `Hermes ${name}`,
      description,
      loadMode: "essential",
      approval: "read",
      parameters: z.object({
        card: z.string().describe("Card id from your first message"),
        token: z.string().describe("Task token from your first message"),
        [field]: z.string(),
      }),
      async execute(_id, params, _signal, _onUpdate, ctx) {
        let text: string;
        let isError = false;
        try {
          const response = await fetch(`${URL}/report`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              card: params.card,
              token: params.token,
              kind: name,
              text: (params as Record<string, string>)[field],
              // The id `omp --resume` takes.
              session_id: ctx?.sessionManager?.getSessionId() ?? "",
            }),
          });
          const reply = await response.json().catch(() => ({}));
          isError = !response.ok;
          text = isError ? String(reply.error ?? `HTTP ${response.status}`) : JSON.stringify(reply);
        } catch (error) {
          isError = true;
          text = `Hermes is unreachable at ${URL}: ${error}`;
        }
        return { content: [{ type: "text", text }], isError, details: {} };
      },
    });
  }
}

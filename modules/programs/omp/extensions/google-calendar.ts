// Read-only Google Calendar via gcalcli.
//
// Managed by nix (modules/programs/omp/extensions/google-calendar.ts).

import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  const z = pi.zod;

  pi.registerTool({
    name: "google_calendar",
    label: "Google Calendar",
    description: `Query and search Google Calendar events using gcalcli. All operations are read-only.

**Available Actions**:
- list_calendars: Show all available calendars
- agenda: Display upcoming events for the next N days (default: 7)
- list_today: Show all events for today
- search: Search for events by keyword (requires query parameter)

Use this tool to check schedules, find meetings, see available calendars, or get event details including meeting links and descriptions.`,
    parameters: z.object({
      action: z
        .enum(["list_calendars", "agenda", "list_today", "search"])
        .describe("Action to perform"),
      query: z
        .string()
        .optional()
        .describe('Search query (required for "search" action)'),
      days: z
        .number()
        .optional()
        .describe('Number of days to show for "agenda" action (default: 7)'),
      calendar: z
        .string()
        .optional()
        .describe("Specific calendar name to query"),
    }),
    approval: "read",

    async execute(_toolCallId, args) {
      const text = (value: string) => ({
        content: [{ type: "text" as const, text: value }],
      });
      const calendar = args.calendar ? ["--calendar", args.calendar] : [];
      let argv: string[];

      switch (args.action) {
        case "list_calendars":
          argv = ["list"];
          break;
        case "agenda":
          argv = [
            "agenda",
            "--details",
            "all",
            ...calendar,
            "today",
            `${args.days ?? 7}d`,
          ];
          break;
        case "list_today":
          argv = ["agenda", "--details", "all", ...calendar, "today"];
          break;
        case "search":
          if (!args.query) {
            return text("Error: query is required for search action");
          }
          argv = ["search", "--details", "all", args.query, ...calendar];
          break;
      }

      try {
        const proc = Bun.spawn(["gcalcli", ...argv], {
          stdout: "pipe",
          stderr: "pipe",
        });
        const [stdout, stderr, code] = await Promise.all([
          new Response(proc.stdout).text(),
          new Response(proc.stderr).text(),
          proc.exited,
        ]);
        if (code === 0) {
          return text(stdout);
        }
        if (
          /Authentication|credentials|OAuth|401|Access denied/i.test(stderr)
        ) {
          return text("Authentication required. Run: gcalcli init");
        }
        return text(`gcalcli command failed: ${stderr || `exit ${code}`}`);
      } catch (error: unknown) {
        const msg = error instanceof Error ? error.message : String(error);
        if (/ENOENT|not found/i.test(msg)) {
          return text(
            "gcalcli not installed. Install it via your package manager.",
          );
        }
        return text(`gcalcli command failed: ${msg}`);
      }
    },
  });
}

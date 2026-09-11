import { tool } from "@opencode-ai/plugin";

// These tools are the jail's only route to the host. HOST_QUERY_PORT is set by
// the jail launcher; outside the jail it is unset and every tool short-circuits
// with an explanation rather than silently doing nothing.
const PORT = process.env.HOST_QUERY_PORT;
const BASE = PORT ? `http://127.0.0.1:${PORT}` : null;

async function post(
  route: string,
  payload: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  if (!BASE) {
    throw new Error(
      "host-query is unavailable: HOST_QUERY_PORT is unset, so this session " +
        "is not running inside the opencode jail. Run the command directly.",
    );
  }
  let response: Response;
  try {
    response = await fetch(`${BASE}${route}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: AbortSignal.timeout(35000),
    });
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : String(error);
    throw new Error(`host-query service unreachable: ${msg}`);
  }
  const data = (await response.json()) as Record<string, unknown>;
  if (!response.ok) {
    throw new Error(`host-query error: ${data.error ?? response.statusText}`);
  }
  return data;
}

function formatRun(data: Record<string, unknown>): string {
  const code = data.exit_code !== 0 ? ` (exit ${data.exit_code})` : "";
  return `$ ${data.command}${code}\n${data.output || "(no output)"}`;
}

export const exec = tool({
  description: `Run a command on the host, outside the sandbox.

Use this for work that genuinely cannot happen inside the sandbox: signing a
commit (the gpg agent is deliberately not reachable from inside), inspecting
system state, or touching paths outside the working directory.

The user approves every call, so state plainly in your message why the command
has to run on the host. Prefer plain bash inside the sandbox whenever it can do
the job. For reading logs use host_journal, which needs no approval.`,
  args: {
    command: tool.schema
      .string()
      .describe(
        "Shell command to run on the host, e.g. \"git commit -S -m 'fix: thing'\" or 'systemctl status sshd'",
      ),
  },
  async execute(args) {
    const command = String(args.command ?? "").trim();
    if (!command) return "Error: empty command";
    return formatRun(await post("/exec", { command }));
  },
});

export const mount = tool({
  description: `Grant a host directory into the sandbox at ~/granted/<name>.

Use this when you need the normal file tools (read, grep, glob, edit) to work
on a directory outside the working directory — another repository, or a config
directory. Read-only unless you pass write.

Takes effect immediately; no restart. The grant lasts for the session and the
user approves each one. Re-granting an existing name remounts it, so switching
a grant from read-only to writable is just another call with write: true.`,
  args: {
    path: tool.schema
      .string()
      .describe(
        "Absolute host directory to grant, e.g. '/var/lib/foo' or '~/dev/other-repo'",
      ),
    name: tool.schema
      .string()
      .optional()
      .describe("Mount name under ~/granted (default: basename of path)"),
    write: tool.schema
      .boolean()
      .optional()
      .describe("Mount read-write instead of read-only (default: false)"),
  },
  async execute(args) {
    const path = String(args.path ?? "").trim();
    if (!path) return "Error: empty path";
    const name = String(args.name ?? "").trim();
    const data = await post("/mount", {
      path,
      ...(name ? { name } : {}),
      write: Boolean(args.write),
    });
    const mode = data.mode === "rw" ? "read-write" : "read-only";
    const how = data.remounted ? "Remounted" : "Mounted";
    return `${how} ${data.source} ${mode} at ${data.jail_path}`;
  },
});

export const journal = tool({
  description: `Read the systemd journal from the host.

Needs no approval: the arguments land in fixed argv positions, never a shell
string. Reading the journal from inside the sandbox is impossible because the
sandbox's user namespace drops the group membership its ACL relies on, so use
this rather than trying journalctl in bash.`,
  args: {
    unit: tool.schema
      .string()
      .optional()
      .describe(
        "Systemd unit to filter by, e.g. 'home-assistant' or 'herdr.service'",
      ),
    lines: tool.schema
      .number()
      .optional()
      .describe("Number of lines to return (default 100, max 5000)"),
    since: tool.schema
      .string()
      .optional()
      .describe(
        "Start of the window, e.g. '10 min ago', 'today', '2026-09-11 13:00'",
      ),
    priority: tool.schema
      .enum([
        "emerg",
        "alert",
        "crit",
        "err",
        "warning",
        "notice",
        "info",
        "debug",
      ])
      .optional()
      .describe("Only show entries at this priority or more severe"),
    boot: tool.schema
      .string()
      .optional()
      .describe("Boot offset: '0' for current boot, '-1' for the previous one"),
    grep: tool.schema
      .string()
      .optional()
      .describe("Filter entries by this pattern"),
    user_units: tool.schema
      .boolean()
      .optional()
      .describe(
        "Read the user journal (systemctl --user) instead of the system one",
      ),
  },
  async execute(args) {
    return formatRun(
      await post("/journal", {
        ...(args.unit ? { unit: args.unit } : {}),
        ...(args.lines !== undefined ? { lines: args.lines } : {}),
        ...(args.since ? { since: args.since } : {}),
        ...(args.priority ? { priority: args.priority } : {}),
        ...(args.boot ? { boot: args.boot } : {}),
        ...(args.grep ? { grep: args.grep } : {}),
        ...(args.user_units ? { user_units: true } : {}),
      }),
    );
  },
});

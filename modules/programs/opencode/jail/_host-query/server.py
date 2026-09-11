#!/usr/bin/env python3
"""host-query: the jail's only route to the host.

Runs outside bubblewrap, started by the jail launcher. The agent reaches it
over loopback; opencode gates /exec and /mount behind an "ask" permission, so
the user approves each one in the TUI before it arrives here.

Usage: host-query <port> [grant-root]
  grant-root enables POST /mount. Without it, mounts are refused.
"""

import http.server
import json
import os
import re
import shutil
import signal
import subprocess
import sys

MAX_OUTPUT = 200_000
TIMEOUT = 30

GRANT_ROOT = None
GRANT_JAIL_PREFIX = "~/granted"
MOUNTS = {}

FUSERMOUNT = "/run/wrappers/bin/fusermount3"

SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")

JOURNAL_PRIORITIES = {
    "emerg",
    "alert",
    "crit",
    "err",
    "warning",
    "notice",
    "info",
    "debug",
}


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.rstrip("/") == "/health":
            return self._json(200, {"status": "ok"})
        self._json(404, {"error": "Use POST /exec, /mount or /journal"})

    def do_POST(self):
        route = self.path.rstrip("/")
        handlers = {
            "/exec": self._exec,
            "/mount": self._mount,
            "/journal": self._journal,
        }
        handler = handlers.get(route)
        if handler is None:
            return self._json(404, {"error": "Use POST /exec, /mount or /journal"})
        body = self._body()
        if body is None:
            return self._json(400, {"error": "Invalid JSON body"})
        handler(body)

    def _exec(self, body):
        command = body.get("command", "").strip()
        if not command:
            return self._json(400, {"error": "Missing 'command' field"})
        try:
            result = subprocess.run(
                command, shell=True, capture_output=True, text=True, timeout=TIMEOUT
            )
        except subprocess.TimeoutExpired:
            return self._json(
                504, {"error": f"Timed out after {TIMEOUT}s", "command": command}
            )
        except Exception as e:  # noqa: BLE001 - surfaced to the agent verbatim
            return self._json(500, {"error": str(e), "command": command})
        self._json(
            200,
            {
                "command": command,
                "exit_code": result.returncode,
                "output": self._merge_output(result),
            },
        )

    def _journal(self, body):
        """journalctl with a fixed argv.

        Separate from /exec because it is auto-approved: the agent never
        supplies a shell string, only values that land in argv positions.
        Needed at all because bubblewrap's user namespace cannot map
        supplementary groups, so inside the jail the process loses the `wheel`
        membership that the journal's ACL grants.
        """
        argv = ["journalctl", "--no-pager", "--no-hostname"]

        unit = body.get("unit")
        if unit is not None:
            unit = str(unit).strip()
            if not re.fullmatch(r"[A-Za-z0-9@._\-\\:]+", unit):
                return self._json(400, {"error": f"Invalid unit: {unit!r}"})
            argv += ["--unit", unit]

        if body.get("user_units"):
            argv.append("--user")

        lines = body.get("lines", 100)
        try:
            lines = int(lines)
        except (TypeError, ValueError):
            return self._json(400, {"error": "lines must be an integer"})
        argv += ["--lines", str(max(1, min(lines, 5000)))]

        since = body.get("since")
        if since is not None:
            since = str(since).strip()
            # journalctl's own parser is permissive; keep the charset boring.
            if not re.fullmatch(r"[A-Za-z0-9 :\-+]+", since):
                return self._json(400, {"error": f"Invalid since: {since!r}"})
            argv += ["--since", since]

        priority = body.get("priority")
        if priority is not None:
            priority = str(priority).strip()
            if priority not in JOURNAL_PRIORITIES:
                return self._json(
                    400,
                    {
                        "error": f"Invalid priority {priority!r}",
                        "allowed": sorted(JOURNAL_PRIORITIES),
                    },
                )
            argv += ["--priority", priority]

        boot = body.get("boot")
        if boot is not None:
            boot = str(boot).strip()
            if not re.fullmatch(r"-?\d+", boot):
                return self._json(
                    400, {"error": "boot must be an integer offset, e.g. 0 or -1"}
                )
            argv += ["--boot", boot]

        if body.get("grep"):
            argv += ["--grep", str(body["grep"])]

        try:
            result = subprocess.run(
                argv, capture_output=True, text=True, timeout=TIMEOUT
            )
        except subprocess.TimeoutExpired:
            return self._json(504, {"error": f"journalctl timed out after {TIMEOUT}s"})
        except FileNotFoundError:
            return self._json(500, {"error": "journalctl not found on the host"})
        self._json(
            200,
            {
                "command": " ".join(argv),
                "exit_code": result.returncode,
                "output": self._merge_output(result),
            },
        )

    def _mount(self, body):
        """bindfs a host directory into the jail's ~/granted.

        bindfs rather than `mount --bind` because this runs unprivileged:
        fusermount3 is setuid so FUSE needs no root, and bindfs has -o ro.
        --no-allow-other is required because /etc/fuse.conf leaves
        user_allow_other commented out.

        The mount lands under the host-side backing dir of the jail's
        ~/granted bind. Since / is `shared`, the new mount propagates into the
        already-running jail with no restart.
        """
        if not GRANT_ROOT:
            return self._json(503, {"error": "Mount grants disabled (no grant root)"})

        src = os.path.realpath(os.path.expanduser(body.get("path", "").strip()))
        if not src or not os.path.isdir(src):
            return self._json(400, {"error": f"Not a directory: {src or '(empty)'}"})

        # Strip leading dots so granting ~/.ssh defaults to "ssh" rather than
        # tripping SAFE_NAME.
        name = (body.get("name") or os.path.basename(src)).strip().lstrip(".")
        if not SAFE_NAME.match(name):
            return self._json(400, {"error": f"Invalid mount name: {name!r}"})

        target = os.path.join(GRANT_ROOT, name)
        write = bool(body.get("write"))

        remounted = False
        if os.path.ismount(target):
            if MOUNTS.get(name) == (src, write):
                return self._json(200, self._mount_result(src, name, write, False))
            u = subprocess.run(
                [FUSERMOUNT, "-u", target],
                capture_output=True,
                text=True,
                timeout=TIMEOUT,
            )
            if u.returncode != 0:
                return self._json(
                    409,
                    {
                        "error": f"Already mounted and could not unmount {name}: "
                        f"{(u.stderr or u.stdout).strip()}"
                    },
                )
            MOUNTS.pop(name, None)
            remounted = True

        bindfs = shutil.which("bindfs")
        if bindfs is None:
            return self._json(500, {"error": "bindfs not found on PATH"})

        try:
            os.makedirs(target, exist_ok=True)
            r = subprocess.run(
                [bindfs, "--no-allow-other"]
                + ([] if write else ["-o", "ro"])
                + [src, target],
                capture_output=True,
                text=True,
                timeout=TIMEOUT,
            )
        except Exception as e:  # noqa: BLE001
            return self._json(500, {"error": str(e)})

        if r.returncode != 0:
            if os.path.isdir(target) and not os.listdir(target):
                os.rmdir(target)
            return self._json(500, {"error": (r.stderr or r.stdout).strip()})

        MOUNTS[name] = (src, write)
        self._json(200, self._mount_result(src, name, write, remounted))

    @staticmethod
    def _mount_result(src, name, write, remounted):
        return {
            "source": src,
            "jail_path": f"{GRANT_JAIL_PREFIX}/{name}",
            "mode": "rw" if write else "ro",
            "remounted": remounted,
        }

    @staticmethod
    def _merge_output(result):
        output = result.stdout
        if result.stderr:
            output += "\n--- stderr ---\n" + result.stderr
        if len(output) > MAX_OUTPUT:
            output = output[:MAX_OUTPUT] + f"\n... (truncated at {MAX_OUTPUT} bytes)"
        return output

    def _body(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            return json.loads(self.rfile.read(length)) if length else {}
        except (json.JSONDecodeError, ValueError):
            return None

    def _json(self, status, data):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 19600
    if len(sys.argv) > 2:
        GRANT_ROOT = sys.argv[2]
        os.makedirs(GRANT_ROOT, exist_ok=True)
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    srv = http.server.HTTPServer(("127.0.0.1", port), Handler)
    print(f"host-query: listening on 127.0.0.1:{port}", flush=True)
    srv.serve_forever()

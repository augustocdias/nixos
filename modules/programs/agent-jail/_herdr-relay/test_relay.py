"""Black-box tests: the real relay process against a recording fake Herdr."""

import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest

SERVER = os.path.join(os.path.dirname(os.path.abspath(__file__)), "server.py")
PANE = "w1:p1"


class FakeHerdr:
    def __init__(self, path):
        self.path = path
        self.requests = []
        self.connections = 0
        self.reply = None
        self.listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.listener.bind(path)
        self.listener.listen(16)
        self.thread = threading.Thread(target=self._serve, daemon=True)
        self.thread.start()

    def _serve(self):
        while True:
            try:
                connection, _ = self.listener.accept()
            except OSError:
                return
            with connection:
                self.connections += 1
                data = b""
                while b"\n" not in data:
                    chunk = connection.recv(65536)
                    if not chunk:
                        break
                    data += chunk
                request = json.loads(data.split(b"\n", 1)[0])
                self.requests.append(request)
                reply = self.reply(request) if self.reply else {"id": request["id"], "result": {"type": "ok"}}
                connection.sendall(reply if isinstance(reply, bytes) else (json.dumps(reply) + "\n").encode())

    def close(self):
        self.listener.close()
        os.unlink(self.path)


class RelayTest(unittest.TestCase):
    agent = "omp"

    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="hr")
        self.upstream_path = os.path.join(self.dir, "up.sock")
        self.listen = os.path.join(self.dir, "relay.sock")
        self.upstream = FakeHerdr(self.upstream_path)
        self.relay = self.start_relay(self.agent)

    def start_relay(self, agent):
        relay = subprocess.Popen(
            [sys.executable, "-I", SERVER, "--listen", self.listen, "--upstream", self.upstream_path,
             "--pane-id", PANE, "--agent", agent],
        )
        for _ in range(100):
            if os.path.exists(self.listen):
                return relay
            time.sleep(0.02)
        relay.kill()
        self.fail("relay did not start")

    def tearDown(self):
        if self.relay.poll() is None:
            self.relay.terminate()
            self.relay.wait(5)
        try:
            self.upstream.close()
        except OSError:
            pass
        shutil.rmtree(self.dir, ignore_errors=True)

    def raw(self, payload, chunks=None):
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(5)
            client.connect(self.listen)
            for chunk in chunks or [payload]:
                client.sendall(chunk)
                if chunks:
                    time.sleep(0.05)
            data = b""
            while b"\n" not in data:
                chunk = client.recv(65536)
                if not chunk:
                    break
                data += chunk
        return json.loads(data)

    def call(self, method, params, request_id="r1"):
        return self.raw((json.dumps({"id": request_id, "method": method, "params": params}) + "\n").encode())

    def metadata(self, **extra):
        params = {"pane_id": PANE, "source": f"user:{self.agent}-activity", "seq": 1,
                  "tokens": {"agent": "build", "title": "t", "todo": ""}, "ttl_ms": 43_200_000}
        params.update(extra)
        return params

    def state(self, **extra):
        params = {"pane_id": PANE, "source": f"herdr:{self.agent}", "agent": self.agent, "state": "working", "seq": 2}
        params.update(extra)
        return params

    def session(self, **extra):
        params = {"pane_id": PANE, "source": f"herdr:{self.agent}", "agent": self.agent, "seq": 3,
                  "agent_session_id": "0199-abc_def", "session_start_source": "startup"}
        params.update(extra)
        return params

    def assertDenied(self, response, code="relay_denied"):
        self.assertEqual(response["error"]["code"], code, response)
        self.assertEqual(self.upstream.connections, 0)

    def assertForwarded(self, response, params):
        self.assertEqual(response.get("result"), {"type": "ok"}, response)
        self.assertEqual(self.upstream.requests[-1]["params"], params)


class OmpTest(RelayTest):
    agent = "omp"

    def test_metadata_forwarded_including_clears(self):
        params = self.metadata(tokens={"agent": "", "title": None, "sub1": "explore: x" * 8})
        self.assertForwarded(self.call("pane.report_metadata", params), params)
        params = self.metadata(tokens={})
        del params["seq"]
        self.assertForwarded(self.call("pane.report_metadata", params), params)

    def test_lifecycle_with_session_path_and_id(self):
        for state in ("working", "blocked", "idle"):
            params = self.state(state=state, agent_session_path="/home/u/.omp/agent/sessions/x/s.jsonl")
            self.assertForwarded(self.call("pane.report_agent", params), params)
        params = self.session(agent_session_path="/home/u/s.jsonl")
        del params["agent_session_id"]
        self.assertForwarded(self.call("pane.report_agent_session", params), params)
        params = self.session()
        self.assertForwarded(self.call("pane.report_agent_session", params), params)
        params = self.session(agent_session_path="/home/u/s.jsonl")
        self.assertForwarded(self.call("pane.report_agent_session", params), params)

    def test_omitted_message_and_nulls_are_dropped(self):
        params = self.state(message=None)
        response = self.call("pane.report_agent", params)
        del params["message"]
        self.assertForwarded(response, params)

    def test_identity_mismatch_denied(self):
        cases = [
            ("pane.report_metadata", self.metadata(pane_id="w1:p2")),
            ("pane.report_metadata", self.metadata(source="user:claude-activity")),
            ("pane.report_agent", self.state(source="herdr:claude")),
            ("pane.report_agent", self.state(agent="claude")),
            ("pane.report_agent_session", self.session(agent="claude")),
        ]
        for method, params in cases:
            self.assertDenied(self.call(method, params))
        params = self.metadata()
        del params["pane_id"]
        self.assertDenied(self.call("pane.report_metadata", params), "invalid_request")

    def test_forbidden_fields_denied(self):
        self.assertDenied(self.call("pane.report_agent", self.state(resume_argv=None)))
        self.assertDenied(self.call("pane.report_agent", self.state(resume_argv=["sh", "-c", "x"])))
        self.assertDenied(self.call("pane.report_agent_session", self.session(resume_argv=["omp"])))
        self.assertDenied(self.call("pane.report_metadata", self.metadata(display_agent="x")))
        self.assertDenied(self.call("pane.report_metadata", self.metadata(tokens={"evil": "x"})))
        self.assertDenied(self.raw(b'{"id":"r","method":"pane.report_agent","params":{},"jsonrpc":"2.0"}\n'))

    def test_malformed_values_rejected(self):
        bad = [
            ("pane.report_agent", self.state(state="done")),
            ("pane.report_agent", self.state(seq=True)),
            ("pane.report_agent", self.state(seq=1 << 64)),
            ("pane.report_agent", self.state(seq=-1)),
            ("pane.report_agent", self.state(seq=1.0)),
            ("pane.report_agent", self.state(message="a\x1bb")),
            ("pane.report_agent", self.state(agent_session_id="-x")),
            ("pane.report_agent", self.state(agent_session_id="a;rm -rf ~")),
            ("pane.report_agent", self.state(agent_session_path="relative/path")),
            ("pane.report_agent", self.state(agent_session_path="/a\nb")),
            ("pane.report_agent_session", self.session(session_start_source="boot")),
            ("pane.report_metadata", self.metadata(tokens={"title": "x" * 81})),
            ("pane.report_metadata", self.metadata(tokens={"title": 1})),
            ("pane.report_metadata", self.metadata(ttl_ms=0)),
            ("pane.report_metadata", self.metadata(ttl_ms=86_400_001)),
        ]
        for method, params in bad:
            self.assertDenied(self.call(method, params), "invalid_request")
        params = self.session()
        del params["agent_session_id"]
        self.assertDenied(self.call("pane.report_agent_session", params), "invalid_request")

    def test_other_methods_denied_without_upstream(self):
        for method in ("ping", "pane.read", "pane.send_input", "pane.send_text", "pane.split", "agent.prompt",
                       "agent.start", "layout.apply", "plugin.action.invoke", "server.stop", "events.subscribe",
                       "pane.clear_agent_authority"):
            self.assertDenied(self.call(method, {"pane_id": PANE, "source": "herdr:omp", "agent": "omp"}))

    def test_framing_rejected(self):
        for payload in (
            b'{"id":"r","id":"r","method":"pane.report_agent","params":{}}\n',
            b'[{"id":"r","method":"pane.report_agent","params":{}}]\n',
            b'"str"\n',
            b'{"id":"r","method":"pane.report_agent","params":{"seq":NaN}}\n',
            b'{"id":"\xff","method":"x","params":{}}\n',
            b'{"id":"\\ud800","method":"x","params":{}}\n',
            b'{"id":"","method":"pane.report_agent","params":{}}\n',
            b"x" * 70_000 + b"\n",
        ):
            self.assertDenied(self.raw(payload), "invalid_request")
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.connect(self.listen)
            client.sendall(b'{"id":"r"')
            client.shutdown(socket.SHUT_WR)
            self.assertEqual(json.loads(client.recv(65536))["error"]["code"], "invalid_request")
        self.assertEqual(self.upstream.connections, 0)

    def test_fragmented_frame_and_trailing_request(self):
        params = self.state()
        line = json.dumps({"id": "r1", "method": "pane.report_agent", "params": params}).encode()
        second = json.dumps({"id": "r2", "method": "pane.send_input", "params": {"pane_id": PANE}}).encode()
        response = self.raw(None, chunks=[line[:10], line[10:40], line[40:] + b"\n" + second + b"\n"])
        self.assertForwarded(response, params)
        self.assertEqual([r["method"] for r in self.upstream.requests], ["pane.report_agent"])

    def test_slow_client_hits_absolute_deadline(self):
        start = time.monotonic()
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(5)
            client.connect(self.listen)
            try:
                for _ in range(10):
                    client.sendall(b" ")
                    time.sleep(0.3)
            except OSError:
                pass
            response = json.loads(client.recv(65536))
        self.assertEqual(response["error"]["code"], "invalid_request")
        self.assertLess(time.monotonic() - start, 3.5)
        self.assertForwarded(self.call("pane.report_agent", self.state()), self.state())

    def test_upstream_error_propagated(self):
        self.upstream.reply = lambda r: {"id": r["id"], "error": {"code": "pane_not_found", "message": "no"}}
        response = self.call("pane.report_agent", self.state())
        self.assertEqual(response, {"id": "r1", "error": {"code": "pane_not_found", "message": "no"}})

    def test_bad_upstream_reply_is_unavailable(self):
        for reply in (lambda r: {"id": "other", "result": {}}, lambda r: b"garbage\n",
                      lambda r: {"id": r["id"], "result": {}, "extra": 1}):
            self.upstream.reply = reply
            self.assertEqual(self.call("pane.report_agent", self.state())["error"]["code"], "upstream_unavailable")

    def test_upstream_down_then_recreated(self):
        self.upstream.close()
        self.assertEqual(self.call("pane.report_agent", self.state())["error"]["code"], "upstream_unavailable")
        self.upstream = FakeHerdr(self.upstream_path)
        self.assertForwarded(self.call("pane.report_agent", self.state()), self.state())

    def test_sigterm_removes_socket(self):
        self.relay.send_signal(signal.SIGTERM)
        self.assertEqual(self.relay.wait(5), 0)
        self.assertFalse(os.path.exists(self.listen))

    def test_refuses_existing_listen_path(self):
        second = subprocess.run(
            [sys.executable, "-I", SERVER, "--listen", self.listen, "--upstream", self.upstream_path,
             "--pane-id", PANE, "--agent", "omp"], capture_output=True, timeout=5)
        self.assertNotEqual(second.returncode, 0)
        self.assertTrue(os.path.exists(self.listen))


class ClaudeTest(RelayTest):
    agent = "claude"

    def test_session_report_drops_transcript(self):
        params = self.session(seq=1_761_120_000_123_456_789, agent_session_id="3f2a9c1e-0000-4000-8000-000000000000",
                              agent_session_path="/home/u/.claude/projects/x/3f2a.jsonl")
        response = self.call("pane.report_agent_session", params)
        del params["agent_session_path"]
        self.assertForwarded(response, params)

    def test_metadata_forwarded_including_clears(self):
        params = self.metadata(tokens={"agent": "claude-opus-5-5", "todo": "1/3 x", "sub1": "Explore: y"})
        self.assertForwarded(self.call("pane.report_metadata", params), params)
        params = self.metadata(tokens={key: "" for key in ("agent", "title", "todo", "sub1", "sub2", "sub3", "submore")})
        self.assertForwarded(self.call("pane.report_metadata", params), params)

    def test_metadata_identity_enforced(self):
        self.assertDenied(self.call("pane.report_metadata", self.metadata(source="user:omp-activity")))
        self.assertDenied(self.call("pane.report_metadata", self.metadata(pane_id="w1:p2")))

    def test_no_lifecycle_reports(self):
        self.assertDenied(self.call("pane.report_agent", self.state()))
        params = self.session(agent_session_path="/home/u/x.jsonl")
        del params["agent_session_id"]
        self.assertDenied(self.call("pane.report_agent_session", params), "invalid_request")


if __name__ == "__main__":
    unittest.main()

import json
import os
import socket
import tempfile
import threading
import unittest
from types import SimpleNamespace

from app_proxy import AppProxy
from server import RelayError


class Fake:
    """A one-line JSON socket that records requests and answers with reply(request)."""

    def __init__(self, path, reply):
        self.requests, self.reply = [], reply
        self.listener = socket.socket(socket.AF_UNIX)
        self.listener.bind(path)
        self.listener.listen()
        threading.Thread(target=self.serve, daemon=True).start()

    def serve(self):
        while True:
            connection, _ = self.listener.accept()
            with connection:
                request = json.loads(connection.makefile().readline())
                self.requests.append(request)
                connection.sendall((json.dumps(self.reply(request)) + "\n").encode())


def app_reply(request):
    if "shot" in request:
        with open(request["shot"], "wb") as file:
            file.write(b"png")
        return {"path": request["shot"]}
    if request.get("do") == "pane.split" and request["args"].get("pane") == "fail":
        return {"error": "no pane"}
    return {"space": "sp1", "tab": "tb1", "pane": "p1", "terminal": "t9"}


class AppProxyTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        root = self.dir.name
        self.workspace = os.path.join(root, "work")
        os.mkdir(self.workspace)
        self.app = Fake(os.path.join(root, "app.sock"), app_reply)
        self.core = Fake(os.path.join(root, "core.sock"), lambda r: {"result": {"address": "t4"}})
        self.proxy = AppProxy(SimpleNamespace(
            upstream=os.path.join(root, "app.sock"), core=os.path.join(root, "core.sock"), workspace=self.workspace))
        self.host_ns, self.proxy.host_ns = self.proxy.host_ns, "pid:[host]"

    def tearDown(self):
        self.dir.cleanup()

    def refused(self, request):
        with self.assertRaises(RelayError):
            self.proxy.handle(request)

    def test_host_code_paths_are_refused(self):
        for name in ("terminal.paste", "mod.open", "layout.set", "app.update", "agents.custom", "window.close"):
            self.refused({"do": name})
        self.refused({"do": "terminal.open", "args": {"argv": ["sh"], "machine": "vps"}})
        self.refused({"do": "tab.new", "args": {"mod": "files", "props": {}}})
        self.refused({"ls": True, "status": True})
        self.assertEqual(self.app.requests, [])

    def test_programs_run_in_the_jail_and_the_app_shows_a_viewer(self):
        reply = self.proxy.handle({"do": "tab.new", "args": {"argv": ["claude"], "task": "fix it"}})
        self.assertEqual(reply["sandbox_terminal"], "t4")
        self.assertEqual(self.core.requests[0]["params"]["argv"], ["claude", "fix it"])
        self.assertEqual(self.core.requests[0]["params"]["cwd"], self.workspace)
        forwarded = self.app.requests[0]["args"]
        self.assertEqual(forwarded, {"argv": ["herdr-core-view", self.proxy.core, "t4"]})

    def test_a_core_outside_the_jail_is_refused(self):
        self.proxy.host_ns = self.host_ns
        self.refused({"do": "terminal.open", "args": {"argv": ["sh"]}})
        self.assertEqual(self.app.requests, [])

    def test_a_refused_view_ends_its_jail_terminal(self):
        reply = self.proxy.handle({"do": "pane.split", "args": {"direction": "right", "pane": "fail"}})
        self.assertIn("error", reply)
        self.assertEqual(self.core.requests[-1]["method"], "terminal.kill")

    def test_only_created_targets_can_be_closed(self):
        self.refused({"do": "pane.close"})
        self.refused({"do": "pane.close", "args": {"pane": "p1"}})
        self.proxy.handle({"do": "terminal.open", "args": {"place": "right"}})
        self.proxy.handle({"do": "pane.close", "args": {"pane": "p1"}})
        # tab.new answers with an existing space; it must not become closable.
        self.refused({"do": "space.close", "args": {"id": "sp1"}})

    def test_screenshots_stay_in_the_workspace(self):
        target = os.path.join(self.workspace, "shot.png")
        self.assertEqual(self.proxy.handle({"shot": target}), {"path": target})
        with open(target, "rb") as file:
            self.assertEqual(file.read(), b"png")
        self.refused({"shot": os.path.join(self.dir.name, "outside.png")})
        os.symlink(self.dir.name, os.path.join(self.workspace, "link"))
        reply = self.proxy.handle({"shot": os.path.join(self.workspace, "link", "escape.png")})
        self.assertIn("error", reply)
        self.assertFalse(os.path.exists(os.path.join(self.dir.name, "escape.png")))


if __name__ == "__main__":
    unittest.main()

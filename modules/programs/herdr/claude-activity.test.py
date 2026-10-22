"""Black-box tests: claude-activity.py per hook event against a recording fake herdr socket."""

import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "claude-activity.py")
PANE = "w1:p1"
SESSION = "3f2a9c1e-0000-4000-8000-000000000000"


class FakeHerdr:
    def __init__(self, path):
        self.requests = []
        self.listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.listener.bind(path)
        self.listener.listen(16)
        threading.Thread(target=self._serve, daemon=True).start()

    def _serve(self):
        while True:
            try:
                connection, _ = self.listener.accept()
            except OSError:
                return
            with connection:
                data = b""
                while b"\n" not in data:
                    chunk = connection.recv(65536)
                    if not chunk:
                        break
                    data += chunk
                request = json.loads(data.split(b"\n", 1)[0])
                self.requests.append(request)
                connection.sendall((json.dumps({"id": request["id"], "result": {"type": "ok"}}) + "\n").encode())


class ActivityTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="ca")
        self.herdr = FakeHerdr(os.path.join(self.dir, "herdr.sock"))
        self.env = {
            "PATH": os.environ["PATH"],
            "HERDR_ENV": "1",
            "HERDR_PANE_ID": PANE,
            "HERDR_SOCKET_PATH": os.path.join(self.dir, "herdr.sock"),
            "CLAUDE_CONFIG_DIR": self.dir,
        }
        self.hook("SessionStart", source="startup", model="claude-opus-5-5")

    def tearDown(self):
        self.herdr.listener.close()
        shutil.rmtree(self.dir, ignore_errors=True)

    def hook(self, name, **fields):
        event = {"hook_event_name": name, "session_id": SESSION, **fields}
        subprocess.run([sys.executable, "-I", SCRIPT], input=json.dumps(event).encode(), env=self.env,
                       check=True, timeout=5)

    def tool(self, name, tool_input, response=None):
        self.hook("PostToolUse", tool_name=name, tool_input=tool_input, tool_response=response or {})

    def last(self):
        params = self.herdr.requests[-1]["params"]
        self.assertEqual((params["pane_id"], params["source"]), (PANE, "user:claude-activity"))
        return params["tokens"]

    def test_session_start_clears_every_token(self):
        self.assertEqual(self.last(), {key: "" for key in ("agent", "title", "todo", "sub1", "sub2", "sub3", "submore")})

    def test_agent_shown_only_while_working(self):
        self.hook("UserPromptSubmit", prompt="hi")
        self.assertEqual(self.last()["agent"], "claude-opus-5-5")
        self.hook("Stop")
        self.assertEqual(self.last()["agent"], "")

    def test_task_progression(self):
        for number in (1, 2):
            self.tool("TaskCreate", {"subject": f"step {number}", "activeForm": f"Doing step {number}"},
                      {"task": {"id": str(number), "subject": f"step {number}"}})
        self.assertEqual(self.last()["todo"], "0/2")
        self.tool("TaskUpdate", {"taskId": "1", "status": "in_progress"})
        self.assertEqual(self.last()["todo"], "0/2 Doing step 1")
        self.tool("TaskUpdate", {"taskId": "1", "status": "completed"})
        self.tool("TaskUpdate", {"taskId": "2", "status": "deleted"})
        self.assertEqual(self.last()["todo"], "")

    def test_todo_write_replaces_list(self):
        self.tool("TodoWrite", {"todos": [
            {"content": "a", "status": "completed", "activeForm": "A-ing"},
            {"content": "b", "status": "in_progress", "activeForm": "B-ing"},
            {"content": "c", "status": "pending", "activeForm": "C-ing"},
        ]})
        self.assertEqual(self.last()["todo"], "1/3 B-ing")

    def test_compact_keeps_tasks_startup_drops_them(self):
        self.tool("TodoWrite", {"todos": [{"content": "a", "status": "pending"}]})
        self.hook("SessionStart", source="compact")
        self.assertEqual(self.last()["todo"], "0/1")
        self.hook("SessionStart", source="resume")
        self.assertEqual(self.last()["todo"], "")

    def test_subagent_slots_and_overflow(self):
        for number in range(4):
            self.hook("PreToolUse", tool_name="Agent", tool_input={"subagent_type": "Explore", "description": f"look {number}"})
            self.hook("SubagentStart", agent_id=f"a{number}", agent_type="Explore")
        tokens = self.last()
        self.assertEqual([tokens["sub1"], tokens["sub2"], tokens["sub3"], tokens["submore"]],
                         ["Explore: look 0", "Explore: look 1", "Explore: look 2", "Explore"])
        self.hook("SubagentStop", agent_id="a0", agent_type="Explore")
        self.assertEqual(self.last()["sub1"], "Explore: look 1")

    def test_subagent_internal_tool_calls_ignored(self):
        count = len(self.herdr.requests)
        self.hook("PostToolUse", agent_id="a9", tool_name="TodoWrite",
                  tool_input={"todos": [{"content": "x", "status": "pending"}]}, tool_response={})
        self.assertEqual(len(self.herdr.requests), count)

    def test_session_end_clears_and_forgets(self):
        self.tool("TodoWrite", {"todos": [{"content": "a", "status": "pending"}]})
        self.hook("UserPromptSubmit", prompt="hi")
        self.hook("SessionEnd", reason="prompt_input_exit")
        self.assertTrue(all(value == "" for value in self.last().values()))
        self.assertFalse(os.path.exists(os.path.join(self.dir, "herdr-activity", SESSION + ".json")))

    def write_transcript(self, entries):
        path = os.path.join(self.dir, "transcript.jsonl")
        with open(path, "w", encoding="utf-8") as handle:
            for entry in entries:
                handle.write(json.dumps(entry) + "\n")
        return path

    def test_title_follows_transcript(self):
        path = self.write_transcript([{"type": "ai-title", "aiTitle": "first"}, {"type": "ai-title", "aiTitle": "Fix  the\nsidebar"}])
        self.hook("UserPromptSubmit", prompt="hi", transcript_path=path)
        self.assertEqual(self.last()["title"], "Fix the sidebar")

    def test_resume_replays_tasks_and_title(self):
        def call(call_id, name, tool_input):
            return {"type": "assistant", "message": {"content": [{"type": "tool_use", "id": call_id, "name": name, "input": tool_input}]}}

        def result(call_id, response=None, error=False):
            return {"type": "user", "toolUseResult": response,
                    "message": {"content": [{"type": "tool_result", "tool_use_id": call_id, "is_error": error}]}}

        path = self.write_transcript([
            call("t1", "TaskCreate", {"subject": "one", "activeForm": "Doing one"}), result("t1", {"task": {"id": "1"}}),
            call("t2", "TaskCreate", {"subject": "two"}), result("t2", {"task": {"id": "2"}}),
            call("t3", "TaskUpdate", {"taskId": "1", "status": "in_progress"}), result("t3"),
            call("t4", "TaskUpdate", {"taskId": "2", "status": "completed"}), result("t4", error=True),
            {**call("t5", "TaskCreate", {"subject": "side"}), "isSidechain": True},
            {"type": "ai-title", "aiTitle": "Resumed work"},
        ])
        self.hook("SessionStart", source="resume", transcript_path=path)
        tokens = self.last()
        self.assertEqual((tokens["todo"], tokens["title"]), ("0/2 Doing one", "Resumed work"))

    def test_idle_notification_hides_agent_after_interrupt(self):
        self.hook("UserPromptSubmit", prompt="hi")
        self.hook("Notification", notification_type="idle_prompt", message="waiting")
        self.assertEqual(self.last()["agent"], "")
        count = len(self.herdr.requests)
        self.hook("Stop")
        self.assertEqual(len(self.herdr.requests), count)

    def test_outside_herdr_is_silent(self):
        count = len(self.herdr.requests)
        self.env["HERDR_ENV"] = "0"
        self.hook("UserPromptSubmit", prompt="hi")
        self.assertEqual(len(self.herdr.requests), count)


if __name__ == "__main__":
    unittest.main()

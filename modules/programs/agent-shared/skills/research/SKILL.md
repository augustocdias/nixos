---
name: research
description: Investigate a question against high-trust primary sources and capture the findings as a Markdown file in the resolved local workspace. Use when the user wants a topic researched, docs or API facts gathered, or reading legwork delegated to a background agent.
---

[Shared workflow](WORKFLOW.md)


For bounded research substantial enough to delegate under the harness rules, use a **background research agent with fresh context**, so you keep working while it reads. Handle a trivial lookup inline. Pass the precise question, source constraints, and resolved absolute workspace explicitly. Research is read-only by default; if the requested investigation needs a research branch or worktree, follow `git-conventions` ownership and parent approvals before mutations. Keep findings in the workspace, never an artifact branch for publication.

Its job:

1. Investigate the question against **primary sources** (official docs, source code, specs, first-party APIs), not a secondary write-up of them. Follow every claim back to the source that owns it.
2. Write the findings to a single Markdown file, citing each claim's source.
3. Save it to `<absolute-workspace>/research/<slug>.md` and report the absolute path. Keep citations, accessed source versions/dates where material, limits, and unresolved questions. Do not invent findings. For remote publication, include the necessary content or approved attachments rather than publishing only an inaccessible workspace link.

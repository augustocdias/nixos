---
name: handoff
description: Compact the current conversation into a handoff document for another agent to pick up.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
---

Read [Shared workflow](WORKFLOW.md) before following this skill.


Write a handoff document summarising the current conversation so a fresh agent can continue the work. Resolve the absolute `.dev-skills/` workspace using the shared workflow, then save to `<workspace>/handoffs/<slug>.md`. If setup is missing, suggest `/setup-dev-skills` in Claude Code or `/skill:setup-dev-skills` in omp before writing the document.

Include a "suggested skills" section in the document. For contextual skills, describe loading through Claude Code's native Skill mechanism or omp's `read skill://name`. For manual skills, suggest the user invoke `/name` in Claude Code or `/skill:name` in omp rather than automatically launching them. Include the absolute workspace path so the next agent does not resolve a different artifact location.

Do not duplicate content already captured in other artifacts (specs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.

Capture the actionable state: current goal, completed work and actual evidence, decisions and rationale, blockers, unresolved questions, and the next concrete actions. Report the absolute handoff path and its access requirements. Another jail or machine may not be able to read this local file; share its content or an approved copy when needed. Do not imply that local artifact links alone are accessible remotely.

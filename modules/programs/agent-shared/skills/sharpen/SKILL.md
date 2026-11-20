---
name: sharpen
description: Rewrite a prompt to ask for a deeper version of the task, not a bigger one.
disable-model-invocation: true
---

[Shared workflow](WORKFLOW.md)

The user wants a deeper version of the task in their prompt, not a bigger one. Before rewriting it, do four things:

1. Say what a top professional in this field would do here that the prompt does not ask for.
2. Name the rawest material they would start from instead of what has already been digested for the user.
3. Name the specific methods and tools they would use.
4. Say what, other than you or the user, would show the result is right.

Then rewrite the prompt to ask for exactly that.

Have the rewritten prompt ask the agent to prototype any choice an experiment can settle and recommend an option based on what it observed. Leave product or preference choices that no experiment can settle for the user to make.

Reply with the four points and the rewritten prompt, then stop. The user decides whether to send it.

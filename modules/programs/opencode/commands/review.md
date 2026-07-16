---
description: Review the current changes (uncommitted, or a branch/PR) with the reviewer subagent
agent: reviewer
subtask: true
---

Review the current changes.

Determine the scope in this order:
1. If arguments name a PR (number/URL) or branch, review that.
2. Else if there are staged changes, review the staged diff.
3. Else review the unstaged working-tree diff.
4. If there are no changes at all, say so and stop.

Gather the diff with read-only git (`git diff`, `git diff --cached`,
`git log`) or the gh read tools for PRs, then produce the review per your
reviewer instructions (findings grouped by Blocking / Should fix / Nit, each
with file:line and a one-line suggestion).

$ARGUMENTS

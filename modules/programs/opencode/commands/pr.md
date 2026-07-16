---
description: Draft a pull request description from the branch diff and open it after approval
agent: build
---

Current branch:

!`git branch --show-current`

Commits on this branch vs the default branch:

!`git log --oneline origin/HEAD..HEAD 2>/dev/null || git log --oneline -20`

Diff summary:

!`git diff origin/HEAD...HEAD --stat 2>/dev/null || git diff --stat`

Draft a pull request for this branch.

- Title: concise summary of the change set.
- Body: a **Summary** section (what and why), a **Changes** bullet list of the
  notable changes, and a **Testing** section describing how it was/should be
  verified. Match any PR template in the repo (.github/) if present.
- Reference related issues/tickets if the branch name or commits mention them.

Show me the title and body first. After I approve, create the PR with the
`gh_pr_write` tool (or `gh pr create`). Push the branch first if needed
(this will prompt for approval).

$ARGUMENTS

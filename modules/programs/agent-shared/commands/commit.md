Staged changes:

!`git diff --cached --stat`

!`git diff --cached`

Recent commit messages (match this repo's style):

!`git log --oneline -15`

Write a commit message for the staged changes above.

- **Conventional Commits**: `type(scope): subject` (feat, fix, refactor, perf,
  docs, test, chore, build, ci, style, revert). Scope optional.
- Subject: imperative mood, lowercase after the colon, no trailing period,
  ≤ 50 chars.
- Body only if the change genuinely needs explaining — why, not what. Keep it
  short; wrap at ~72 chars. Most commits need no body.
- Still respect any stricter convention in AGENTS.md or visible in recent
  commits.
- If nothing is staged, say so and stop — do not stage anything yourself.

Be terse: show only the proposed message, then commit it. Signing only works on
the host, so inside the sandbox use `host_exec` (it prompts for approval). No preamble, no summary. Do not push.

$ARGUMENTS

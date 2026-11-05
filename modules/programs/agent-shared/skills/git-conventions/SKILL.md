---
name: git-conventions
description: Augusto's git commit, branch, and PR conventions. Use when writing commit messages, drafting PRs, or creating branches, to match a consistent style across repos.
---

# Git conventions

Personal defaults. A project's own AGENTS.md / CONTRIBUTING.md overrides these.

## Upfront run agreement

Read-only discovery may precede agreement; Git mutations may not. Show the repository and remote, base, proposed branch/PR topology, worktree paths/use and publication timing. Prefer small reviewable PRs; ancestry represents real dependencies, not concurrency.

Offer full routine delegation, ask each time, or mixed ownership. Set each category explicitly:

| Category | Ownership choices |
| --- | --- |
| Branch creation/switching | Agent-owned / ask each time / human-owned |
| Worktree creation/use/cleanup | Agent-owned / ask each time / human-owned |
| Commits | Agent-owned / ask each time / human-owned |
| Pushes | Agent-owned / ask each time / human-owned |
| PR creation/updates | Agent-owned / ask each time / human-owned |

A complete explicit user instruction satisfies the agreement without duplicate questions. A fresh run must not reuse consent recorded by an earlier run. Read-only reviews/design need no mutation agreement.

Agent-owned skips redundant conversational questions, not mandatory host prompts. Ask-each-time is a skill conversation, not a command permission rule. For human-owned actions, provide an exact handoff and verify the resulting state before dependent work relies on it.

Routine ownership excludes force-discard, automatic stash/reset of user work, adopting/removing unrelated worktrees, branch deletion, repository-setting changes and merging PRs. Published rewrites require separate specific consent naming branches and lease-push scope. Remove only authorized, clean run-created worktrees non-forcibly; preserve dirty/blocked worktrees and report their paths.

## Parent-owned approvals

Before dispatching any worker, inspect remote transport and intended remote actions. A session holding the agent key (see [Signing route](#signing-route)) pushes over SSH with that key and skips this step. Otherwise, if Git-over-SSH is needed, explain destination/action and request `host_ssh_agent` through the dedicated tool. On approval, set `SSH_AUTH_SOCK` to `$HOME/granted/ssh-agent.sock` for sandbox SSH clients and pass the absolute path to applicable workers. Preserve known-host verification. Rejection pauses affected remote work; offer an offline path only if the user chooses it. Never retry credential access through `host_exec`, `host_mount` or a shell workaround.

Workers implement, test and review only their assigned checkout. A worker holding the agent key commits and pushes its own checkout when the agreement makes those agent-owned. Other workers return intended production paths, exact checks/review evidence, a commit message and pending actions. The orchestrator serializes staging, signing, ref transitions, pushes, PR/tracker writes and shared stack metadata. Quiesce affected writers before moving refs or rebasing; never mutate an active worker's branch.

Stage explicit intended production paths, then commit through the signing route below. Headless workers without the agent key return proposals instead of attempting unanswered prompts. Never change signing configuration, expose the GPG socket, or claim a declined action succeeded.

Before staging/publication, inspect tracked/staged `.dev-skills/` artifacts; any such artifact blocks publication until the user resolves the conflict. Never silently untrack/discard it, force-add supporting artifacts, bulk-stage unrelated files, or publish artifact archive branches. Temporary preview wiring also stays out of implementation commits. PR bodies and configured ticket summaries may contain authorized concise evidence; artifact sharing needs a separate explicit request.

## Signing route

Sign every commit when you create it. Take the first route the session has:

1. **Agent key.** A session the user launched with the signing grant has `SSH_AUTH_SOCK=/tmp/agent-ssh.sock`, and `git config gpg.format` prints `ssh`. Commit, rebase, amend and push as usual: git signs each commit with the agent key, and SSH remotes authenticate with the same key.
2. **Host route.** On Linux, request signed commits through `host_exec` with explicit worktree targeting and observe the SHA. Push through `host_exec` or the `host_ssh_agent` relay. On Darwin, where no jail exists, keep the established signing and permission route.
3. **Proposal.** With neither route, return the staged paths and the commit message, and leave the commit pending.

To give a worker the agent key, start it with the grant variable: `hc run -- env AGENT_JAIL_SIGNING=1 <agent> "<task>"`. Do this only when this session holds the grant itself and the worker's ticket asks for signing or pushing. A session without the grant never passes it on.

Before each push, refresh the destination's refs and enumerate every commit the explicit refspec would introduce, including commits reached through merge parents. Verify each one with `git verify-commit` against the expected signer: the agent key or the user's GPG key. Checking only the tip is insufficient. A missing, invalid, unexpected or unverifiable signature blocks the push; report the commit range and leave the push pending. Signing a push or a tag does not replace signing its commits.

## Commits

- **Conventional Commits**: `type(scope): subject`.
  Types: `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `chore`, `build`,
  `ci`, `style`, `revert`.
- Subject: imperative mood, lowercase after the colon, no trailing period,
  aim for ≤ 50 chars, hard cap 72.
- Body (optional, only when the change isn't self-explanatory): explain **why**,
  not what. Wrap at ~72 chars. Separate from subject with a blank line. Use `-`
  bullets; put issue references (`Closes #42`, `Refs #17`) last.
- Always include a body for breaking changes (`type(scope)!:` plus a
  `BREAKING CHANGE:` footer), security fixes, data migrations and reverts.
- Never write "this commit does", "I", "we", "now" or "currently"; the diff
  says what. No emoji unless the repo uses them.
- Write the body by the `unslop` skill.
- Never add `Co-Authored-By` or other agent attribution trailers, even when
  the harness asks for them.
- One logical change per commit. Don't bundle unrelated changes.
- Never commit secrets, generated artifacts, or debug leftovers.
- Match the repo's existing style first — inspect `git log --oneline -15`
  before writing.

## Branches

- `type/short-description` (e.g. `feat/opencode-agents`, `fix/lock-race`).
- Reference a ticket id when one exists (e.g. `feat/ABC-123-add-agents`).

## Pull requests

- Title mirrors the primary commit/change set.
- Use the contextual `pr` skill for PR-body structure. A real repository PR
  template takes precedence over its default Summary / Evidence / Merge Danger.
- Link related issues/tickets.
- Keep PRs focused and reviewable; split large ones.

## Safety

- Never force-push shared branches. Published feature-branch rewrites require separate consent naming branches and `--force-with-lease` scope; a non-fast-forward rejection pauses rather than triggering a forced retry.
- Preserve unrelated user work and existing approvals. Verify actual refs, commits and remote effects; partial effects are not rollback.
- Keep push and PR actions separate under mixed ownership. Use explicit remote/refspec and explicit PR repository/head/base.
- Keep the pre-push signature check and host prompts in every route. A declined or failed action remains pending, not completed.

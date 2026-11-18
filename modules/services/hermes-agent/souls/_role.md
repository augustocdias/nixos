
# Working directly in Hermes

Use your configured model and native tools to perform the assignment yourself. Read the ticket and repository instructions before editing.

A delegated helper does not own the parent's board task or Git grant. Review supplied evidence and files; leave Git operations and board transitions to the owning worker. When requesting such a check, supply the diff, exact base/head and acceptance criteria rather than asking the helper to borrow your task ID.

The card's Run settings contain Repo, Tracker and Git ownership. Repo names the exact checkout; one card changes one repository. Native workers must use that directory as their workspace. If the workspace and Repo disagree, stop and request correction rather than writing elsewhere. Decomposed work inherits its parent's settings. Preserve exclusive checkout ownership between implementation and review.

# Git ownership

Use the `git` tool for every Git operation, including reads. Pass the current task ID and an array of arguments without the `git` executable. For example, `{"task":"<card-id>","args":["status","--short"]}`. Terminal Git is blocked. Credentials remain inside the proxy; never request a key or signing socket. The proxy replaces the credential, signing and worker-proposal sections of `git-conventions`; take only its ownership scope and commit style.

Ownership is independently `agent` or `human` for branches, worktrees, commits, pushes and PRs. Missing values and legacy `ask` mean human. The proxy enforces branch, worktree, commit and push ownership. Honor PR ownership before using publication tools. A human-owned operation means prepare the exact handoff and leave it to the user, not ask for approval in a background terminal. Existing grants are not permission to merge, force-push or delete unrelated work. All created commits must be signed, and every outgoing commit must pass signature verification.

Keep task run settings unchanged. A changed Git agreement needs a human edit and, after first Git use, the user's `hermes git-policy <card-id>` command. A child card cannot broaden your repository or Git grant. Bring cross-repository work to the coordinator as a separately scoped assignment.

# Board lifecycle

1. Record the intended scope and the acceptance checks with `kanban_comment`.
2. Perform the work, observe the changed behavior, and collect all delegated results before handing off. Tests alone do not establish a UI or service works.
3. Record exact checkout, branch, base/head, changed behavior, check outcomes, signature evidence, skills loaded and any human-owned handoff.
4. End the stage with the appropriate board action. Programmers request independent review on the same card with `kanban_request_review`; reviewers follow `sdlc-review`; research and QA complete when their assignment is verified.

Use `kanban_block` only for a prerequisite or decision no agent can resolve. Put evidence, logs and prepared text in an ordinary comment first. Then post the block note as the card's last comment and pass the same text as the block reason. The user reads only the block note, so keep it under 60 words, in exactly this shape:

```markdown
## ⛔ Blocked: <what the user must do, in one line>

**Why:** <one sentence the user can see, such as "`gh` has no GitHub login in the reviewer sandbox">

- **A. <action>:** <what happens next>
- **B. <action>:** <what happens next>
``` Background runs never wait on invisible approval prompts. A human-owned publication step is a handoff; keep the card blocked only when it prevents a required acceptance check. Otherwise disclose it as remaining human work.

Create assigned work with `triage=false`, an explicit assignee and all blocking parents. Only the coordinator in a direct user conversation may create explicitly requested triage work. Board Done means approved and verified agent work, not merged, deployed or externally closed. An open predecessor PR is not itself a blocker.

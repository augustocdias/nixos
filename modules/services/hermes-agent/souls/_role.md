
# Working directly in Hermes

Use your configured model and native tools to perform the assignment yourself. Read the ticket and repository instructions before editing.

A delegated helper does not own the parent's board task. Review supplied evidence and files; leave Git operations and board transitions to the owning worker. When requesting such a check, supply the diff, exact base/head and acceptance criteria rather than asking the helper to borrow your task ID.

The card's Run settings contain Repo, Tracker and an optional Git branch. Repo names the exact checkout; one card changes one repository. Native workers must use that directory as their workspace. If the workspace and Repo disagree, stop and request correction rather than writing elsewhere. Decomposed work inherits its parent's settings. Preserve exclusive checkout ownership between implementation and review.

# Git

You own branches, worktrees, commits, pushes and PRs; follow the `git` skill. Where a shared skill says to load `git-conventions` or agree Git ownership, load `git` instead: that agreement is already settled. Run Git in the terminal against the card's checkout. Its Git config signs every commit and tag with the agent SSH key; keep that config and add no other key, signing program or credential helper. Merging, force-pushing and deleting unrelated work need the user. A child card cannot change your repository. Bring cross-repository work to the coordinator as a separately scoped assignment.

# Board lifecycle

1. Record the intended scope and the acceptance checks with `kanban_comment`.
2. Perform the work, observe the changed behavior, and collect all delegated results before handing off. Tests alone do not establish a UI or service works.
3. Hand off in at most 120 words: the outcome in one line, branch, base..head, each check with pass or fail, skills loaded in one line, and what the user must do, if anything. The diff shows what changed; leave narration and logs out.
4. End the stage with the appropriate board action. Programmers end their stage by calling `kanban_request_review` on the same card with `reviewer="reviewer"`, after the handoff comment; reviewers follow `sdlc-review`; research and QA complete when their assignment is verified.

Keep every other comment under 60 words. Put longer evidence, such as logs, in a file attached with `kanban_attach` and name it in one line.

Use `kanban_block` only for a prerequisite or decision no agent can resolve. Attach its evidence first, then post the block note as the card's last comment and pass the same text as the block reason. The user reads only the block note, so keep it under 60 words, in exactly this shape:

```markdown
## ⛔ Blocked: <what the user must do, in one line>

**Why:** <one sentence the user can see, such as "`gh` has no GitHub login in the reviewer sandbox">

- **A. <action>:** <what happens next>
- **B. <action>:** <what happens next>
```

Background runs never wait on invisible approval prompts.

Create assigned work with `triage=false`, an explicit assignee and all blocking parents. Only the coordinator in a direct user conversation may create explicitly requested triage work. Board Done means approved and verified agent work, not merged, deployed or externally closed. An open predecessor PR is not itself a blocker.

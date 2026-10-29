# Stack and worktree procedure

Read this companion before `implement-spec` prepares checkouts or publishes. `git-conventions` owns the five-category agreement, parent approvals and safety; this file owns topology, runtime constraints and version-specific mechanics.

## Topology and scheduling

Default to one reviewable ticket per PR; group only when acceptance boundaries require it. A dependent layer targets its immediate parent branch. Independent work uses independent PRs/stacks. Worktree concurrency is not PR ancestry. At joins, propose a reviewable grouping/order without inventing dependencies or accumulating unrelated changes in each diff. Explain genuinely inseparable scope before coding.

Agree publication timing upfront: verified-layer incremental drafts (recommended), after full-spec verification, or human publication. Draft-ready transitions and tracker closure follow separate authorization/policy. An open remote ticket is not a blocker once prerequisite implementation and required commits are verified.

A chain's final tip contains its complete result. Multiple independent tips may need an agreed local-only integration branch/worktree for cross-ticket verification. It gets no aggregate PR. Apply review fixes to the owning layers, then update descendants under rewrite consent where necessary; never leave fixes only on integration.

## Assigned checkouts and shared workspace

Agree persistent accessible paths before creation. Default to `<absolute-workspace>/worktrees/<run>/<ticket>` inside locally excluded `.dev-skills/`; another established location must be accessible and explicitly approved. Never silently use sibling paths in session-private tmpfs or broaden mounts.

Each worker gets its absolute source checkout, branch, parent/review-base SHA, prerequisite commits and the parent's absolute supporting workspace. Confirm actual cwd/branch/prerequisite SHA before coding. The supplied supporting workspace is a narrow exception to normal Git-root discovery: use it even outside the child's root, do not initialize a duplicate, and keep evidence in distinct local paths. Only the parent writes `features/<slug>/progress.md`.

Ignored fixtures, credentials and databases do not appear automatically in worktrees. Verify required inputs before dispatch, reuse authorized resources only, and never blindly copy secrets. Unrun required checks are not success. Isolate ports/data or serialize conflicting checks. Maintain one active writer per worktree. Quiesce affected workers before moving refs, rebasing or updating checkouts. Never mutate another active writer's branch. Non-forced cleanup requires authorization, clean run-created worktrees and durable results/evidence; preserve blocked/dirty worktrees with exact paths.

## Verified command procedure

The installed executable is `gh-stack`; use it directly. No package/input change, installer or extension discovery is needed. Do not run `gh stack --version`: earlier discovery unexpectedly installed a registered extension.

Consult [versioned command semantics](https://github.com/github/gh-stack/blob/v0.2.1/skills/gh-stack/references/commands.md) and installed subcommand help. The following separates actions to honor mixed ownership even under full routine delegation.

1. Inspect explicit remote/repository/base, authentication, existing stack membership and worktree ownership. GitHub code hosting determines eligibility; ticket trackers are independent. Missing native stack support requires a reported fallback choice, not silent ordinary-PR conversion or changed repository settings.

1. The parent creates/adopts approved layers with `gh-stack init --base <base> <first-branch>` and `gh-stack add <branch>` from a valid stack context, coordinating explicit worktree creation. `init` enables Git rerere: disclose that side effect. `add` requires the current top (or trunk of an empty stack). Existing branches owned by another worktree may be adopted without switching the invoking checkout: verify actual identity afterward. Never use staging/commit shortcuts `-A`, `-u` or `-m`; do not let uncommitted changes carry across layers.

1. Commit each layer through the parent approval route before its dependent layer starts. Record the observed SHA and each layer's actual parent/review base so review and PR diffs exclude earlier layers.

1. Push separately through the parent's required host route using explicit non-force `git push <remote> <branch>:refs/heads/<branch>`. A non-fast-forward rejection pauses for specific published-rewrite consent; no automatic forced retry. Verify the expected remote commit.

1. Load `pr` skill; follow the actual repository template. Create with explicit `gh pr create --repo <owner/repo> --base <parent-branch> --head <branch> --draft --title <title> --body-file <file>`. Keep the body file local to the supporting workspace and never stage it. Preserve unrelated content in existing PRs. [GitHub CLI documentation](https://cli.github.com/manual/gh_pr_create) states explicit `--head` avoids implicit pushing/forking; `--dry-run` may still push, so it is not a harmless validation substitute.

1. Under PR-update ownership, link verified full URLs bottom-to-top: `gh-stack link --remote <remote> --base <base> <pr-url> <pr-url> ...`. Branch-name arguments can push/create PRs; numeric arguments can resolve ambiguously. Use full URLs only. Verify actual remote PR bases and stack membership, not just the exit code. Linking is additive; do not silently remove or reassign membership.

1. Avoid coupled `submit`, `sync`, push, merge/prune/unstack shortcuts in routine orchestration. Installed push/submit can use force-with-lease and leave partial effects. Lower-layer fixes require quiescing affected workers, updating only authorized clean owning worktrees and separate consent before published rewrites. Preserve signing and conflict recovery; no automatic stash/reset. Do not merge PRs as an implicit finish step.

1. Partial remote effects are not rollback. Re-read actual refs, PRs and membership, then retry only missing approved actions. Unsupported native stacks trigger the agreed fallback question. Never claim a stack exists from command success alone. Without an approved disposable remote, command/help checks are not proof of GitHub compatibility.

---
name: implement-spec
description: Orchestrate a complete spec through fresh ticket implementers and small reviewable PRs or stacks.
disable-model-invocation: true
---

[Shared workflow](WORKFLOW.md)

Complete the supplied specification through its ticket **task graph**. The parent orchestrates; it does not implement tickets itself. Start every implementer with fresh context, including when only one ticket is ready. Communicate through accessible context pointers rather than duplicated payloads.

## Steps

1. **Load and agree.** Read the full spec, ticket bodies/comments, acceptance criteria, blocking graph and existing work through the actual configured tracker. Resolve the absolute workspace and its `issue-tracker.md`, `domain.md` and standards. Missing required setup needs the user's manual `setup-dev-skills` invocation. Load `git-conventions`; agree five-category ownership, reviewable branch/PR topology, unsettled test seams and publication timing. Read [Stack and worktree procedure](STACKS.md) before preparing checkouts or publication. Inspect transport and intended remote actions: when Git-over-SSH is needed, obtain dedicated `host_ssh_agent` approval **before starting any subagent**. A refusal pauses affected remote work without another credential route.

1. **Explore concrete unknowns only.** Optionally dispatch fresh-context exploration with spec/code pointers and writable notes under the retained workspace. Do not require exploration when no unknown remains. Preserve unrelated work; clarify cycles or unresolved dependencies before affected coding.

1. **Prepare the frontier.** Follow the ownership agreement to assign branches and, if authorized, distinct worktrees. The frontier contains tickets with verified prerequisite implementation and required actual commits—not merely closed remote issues. An open PR can satisfy a dependency; failed required verification blocks successors but not independent tickets. Confirm required fixtures, credentials and databases without blindly copying secrets. Isolate shared test ports/data or serialize checks.

1. **Dispatch fresh implementers.** Explicitly instruct each child to invoke `implement` through Claude's native Skill mechanism or omp's `read skill://implement`. With authorized distinct worktrees, run independent ready tickets concurrently. Without worktree permission, run one child at a time in the current checkout. Pass spec/ticket pointers, precise production scope, agreed seams, absolute checkout and branch, parent/review-base SHA, prerequisite commits, absolute supporting workspace/configuration and inherited ownership. Require confirmation of actual cwd/ref/prerequisite SHA before coding. Generic delegation economy must not remove this per-ticket isolation.

1. **Integrate evidence, not parent code.** Children return acceptance/check evidence, ticket-scoped review outcome, intended production paths, commit message and exact pending actions. If nesting reviewers is unavailable, dispatch their requested ticket-scoped review from the parent. Serialize shared Git lifecycle, staging/signing, ref transitions, stack metadata, tracker writes and publication even while isolated coding runs concurrently. Stage only intended production files; supporting artifacts and temporary preview wiring block publication if tracked/staged. Request signed commits and approved pushes through the parent's required host route and observe actual SHAs. A declined commit stays pending. Recompute the frontier after verified commits; never wait for remote issue closure unnecessarily.

1. **Review the result once.** Review each layer against its own ticket and parent commit. When all work exists, run cross-ticket checks and one whole-spec `code-review`. A chain's final tip contains its result; multiple tips may require an agreed local-only integration branch/worktree. Never propose an aggregate PR. Send supported findings to fresh implementers on the owning layer(s), update affected descendants only after quiescing their writers, then run focused checks. Do not leave fixes solely on the temporary integration branch or launch an unbounded whole-spec review loop. Failed required checks or missing acceptance criteria remain blockers.

1. **Finish agreed actions.** Complete authorized publication and tracker actions under their separate policies; commits do not imply closure. Mark drafts ready only when authorized. Report small PRs/stacks, actual commits, evidence, blockers and remaining human handoffs. Clean only authorized clean run-created worktrees non-forcibly after durable results; retain dirty/unresolved worktrees with exact paths.

## Parent-owned progress

Reuse `features/<slug>/progress.md` under the parent's absolute workspace; no new tracker schema or orchestration engine. Preserve existing notes and record assignments, dependency state, commit/review-base SHAs, PR URLs, current-run ownership and pending approvals. Track implementation, commit, publication and tracker closure separately. Workers write distinct evidence artifacts, never race on shared progress. Remote updates contain only authorized concise status/evidence summaries, not automatic copies of the local record.

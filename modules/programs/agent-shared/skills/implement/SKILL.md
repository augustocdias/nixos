---
name: implement
description: "Use when implementing user-requested work from a spec or tickets, or an explicitly assigned orchestrator or board ticket."
---

[Shared workflow](WORKFLOW.md)

Runs on manual invocation, on user-requested implementation, and on explicit orchestrator assignments; all three follow this workflow.

Implement the assigned work using the agreed checkout and Git ownership from `git-conventions`. Direct invocation establishes that agreement before mutations; delegated invocation inherits it and returns approval-dependent actions to the parent. Confirm the actual absolute cwd, branch, review-base SHA and prerequisite commits before coding. Do not mutate another worker's checkout or refs.

Resolve and retain the absolute `.dev-skills/` workspace path using the shared workflow. Read `issue-tracker.md`, `domain.md`, and applicable coding standards there. If required configuration is absent, suggest the user invoke `setup-dev-skills`. Do not invoke that manual-only skill automatically.

If given a ticket reference, fetch its full body, comments, blockers and relevant specification using the configured tracker. State its title before starting. For local work, use the resolved workspace's `features/<slug>/spec.md` and ticket under `features/<slug>/issues/`. Resolve discoverable references with tools; ask only if genuinely ambiguous. Dependency satisfaction means verified implementation and required commits, not remote ticket closure; an open PR need not block a dependent assignment.

Read the applicable project rules, domain glossary, ADRs, and existing changes before editing. Preserve unrelated user work. Reuse agreed test seams; do not reopen settled seam choices without new evidence.

Load `tdd`. Build through the agreed public-behavior seam in vertical red/green cycles. Write comments by the shared workflow's comment rule, and remove comments your own change added that break it before review. Accept user-reported failure evidence rather than rerunning merely to confirm it; seek causal evidence and exercise the changed behavior. Run relevant single test files and typechecking during implementation where applicable, then the required project checks and full test suite once at the end. Record exact outcomes, including checks unavailable in this environment. A failed or unrun required validation is not a pass.

Once done, load `code-review` to review the actual ticket diff against its supplied parent/review-base commit, standards and spec. Address supported findings, then run checks affected by fixes. If nested reviewers are unavailable, ask the parent to dispatch the ticket-scoped review; do not omit it. Failed required checks or blocking findings leave the ticket incomplete.

Return acceptance/check evidence, review outcome, exact intended production paths, a commit message and pending parent actions. A delegated worker does not stage, sign, push, move refs, publish or write shared progress. Save separate evidence under the parent's absolute workspace. Direct invocation follows `git-conventions` ownership and the existing signed-commit route; a declined commit remains uncommitted. Exclude all supporting artifacts and temporary prototype wiring.

Keep implementation, commit, publication and tracker closure status separate. Update the configured tracker only through its approval route and actual closure policy. Report behavior, exercised checks, review outcome, actual commit status and blockers. Pushes and PRs require agreed publication scope.

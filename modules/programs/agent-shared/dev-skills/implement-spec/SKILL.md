---
name: implement-spec
description: "Implement the result of to-spec and to-tickets sequentially in the current checkout."
disable-model-invocation: true
---

[Shared workflow](WORKFLOW.md)

You have been provided a spec with associated tickets describing its implementation. Complete the whole specification through a dependency-ordered loop in the user's current checkout and current branch. The human chooses the checkout and branch.

Resolve and retain the absolute `.dev-skills/` workspace path using the shared workflow. Read `issue-tracker.md`, `domain.md`, and applicable coding standards there. If required configuration is absent, suggest manual setup: Claude `/setup-dev-skills`; omp `/skill:setup-dev-skills`. Do not invoke that manual-only skill automatically.

The tickets form a **task graph**, not merely a list of steps. The **frontier** contains tickets whose blockers have completed successfully. Execute **one coding task at a time**, even when several frontier tickets are ready. Failed validation blocks dependent tickets.

Never create, manage, merge, or delete worktrees; create, switch, reset, or merge branches; or delegate those operations through agents or host tools. There is no integration branch or merger-agent lifecycle. Preserve unrelated changes without hiding them in a stash or reset.

Communicate through context pointers to the spec, tickets, research, relevant code, and actual commits. Pass the resolved absolute workspace path explicitly to any delegate. Do not duplicate context already available through accessible pointers.

## Steps

### 1. Load the specification and graph

Read the full spec, ticket bodies, comments, acceptance criteria, blocking edges, and current statuses using the configured tracker. For local work, use `.dev-skills/features/<slug>/spec.md` and one ticket per file in `features/<slug>/issues/`. Resolve real references, not invented identifiers.

Confirm the destination and already-agreed test seams. Inspect the current checkout and existing changes before editing; identify overlapping user changes without discarding them. Record a concise graph and current state in `.dev-skills/features/<slug>/progress.md`, preserving existing notes. Record blockers and any missing prerequisites rather than guessing. A cycle or unresolved dependency must be clarified before executing affected tickets.

### 2. Explore only where needed

Use existing code and primary documentation to answer concrete unknowns. Apply existing delegation rules: bounded read-only exploration or review may run in parallel when justified, but no concurrent implementation tasks. Save durable research under `.dev-skills/research/<slug>.md`, and point from progress or tickets to it. Do not create research branches or write notes outside the resolved workspace.

### 3. Select one runnable ticket

Recompute the frontier from actual dependency outcomes. Select one unblocked ticket in dependency order; respect an explicit user selection if runnable. State its title, delivered behavior, blockers, and acceptance criteria. Use the configured approval route for any remote claim or status update. Do not treat an unapproved tracker write as completed.

If the frontier is empty while unfinished tickets remain, stop coding and report the concrete blocker or graph inconsistency. Never bypass a failed predecessor to keep moving.

### 4. Build through the agreed seam

Load contextual `tdd` through Claude's native Skill mechanism or omp's `read skill://tdd`. Reuse the agreed seams and implement the complete vertical slice in red/green cycles against public behavior. Accept user-provided failure evidence; do not rerun merely to prove the report. Keep the change scoped to the ticket and agreed complete cutover, without speculative compatibility paths.

The parent may implement directly or use one bounded coding delegate, but must wait for that task to finish before starting another coding task. Give any delegate the ticket/spec pointers, exact scope, absolute workspace path, test seam, and current-checkout/no-branch-management constraints.

### 5. Verify and review the ticket

Exercise the changed behavior and all ticket acceptance criteria. Run relevant tests, typechecking, and required project checks. Record exact commands and observed results; distinguish failures, unavailable checks, and passes. Load contextual `code-review` through the same harness mechanism against the actual ticket diff, standards, and spec. Address supported findings and rerun checks affected by fixes.

A failed required check, incomplete acceptance criterion, or unresolved blocking review finding leaves the ticket incomplete. Record the failure in progress and keep downstream tickets blocked. Fix the issue before selecting another ticket; if missing access or a human decision prevents this, report that exact prerequisite.

### 6. Commit and update progress truthfully

Commit the intended ticket change on the current branch through `git-conventions` and the existing signed-commit approval route. Never stage unrelated work or bypass signing/approval. If approval is declined, retain the changes, record **verified but uncommitted**, and do not claim a commit or close a ticket whose configured completion policy requires one. Obtain the missing decision before continuing when it affects downstream completion.

Record acceptance results, review outcome, actual commit identifier if created, and remaining risks in `features/<slug>/progress.md`. Update local ticket status consistently. Propose remote comments/status/closure using `issue-tracker.md` and its normal approval route; do not claim an unapproved or failed write succeeded. Remote summaries must contain the needed content or approved accessible attachments, not only a local `.dev-skills/` link.

Recompute the frontier and repeat steps 3–6, one coding task at a time. A ticket becomes a satisfied dependency only after its required verification and completion policy succeed.

### 7. Verify the entire specification

Once every ticket is complete, exercise cross-ticket behavior and run the full required checks/test suite. Load `code-review` for the whole specification's actual diff, keeping Standards and Spec reports separate. Fix supported findings in the current checkout, one coding task at a time, and repeat affected validation. Do not declare completion until all acceptance criteria and required checks are satisfied, or report exact remaining blockers.

### 8. Finish through approved tracker and PR actions

Resolve tickets and the spec only as the configured tracker policy permits and through normal approval. When requested and approved, use contextual `pr` to draft or update a PR **for the current branch only**, including accurate issue references and observed evidence. Push, PR creation, and marking a draft ready remain explicit approved actions; tracker preference for PR closure is not implicit permission to publish.

Report the specification outcome, ticket/dependency status, exercised verification, review findings addressed, actual commits, and approved tracker/PR actions. Leave the user's checkout, branch, unrelated changes, and any human-managed worktrees intact.

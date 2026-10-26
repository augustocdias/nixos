---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

[Shared workflow](WORKFLOW.md)

Implement the work described by the user in the spec or tickets, in the user's current checkout and current branch only. Never create or manage worktrees, switch or reset branches, or delegate those operations.

Resolve and retain the absolute `.dev-skills/` workspace path using the shared workflow. Read `issue-tracker.md`, `domain.md`, and applicable coding standards there. If required configuration is absent, suggest manual setup: Claude `/setup-dev-skills`; omp `/skill:setup-dev-skills`. Do not invoke that manual-only skill automatically.

If the user passes a ticket reference, fetch its full body, comments, blockers, and relevant specification using the configured tracker. State its title before starting. For local work, read `.dev-skills/features/<slug>/spec.md` and the individual ticket under `features/<slug>/issues/`. Resolve discoverable references with tools; ask only if genuinely ambiguous. Do not begin a blocked ticket.

Read the applicable project rules, domain glossary, ADRs, and existing changes before editing. Preserve unrelated user work. Reuse agreed test seams; do not reopen settled seam choices without new evidence.

Load `tdd` through Claude's native Skill mechanism or omp's `read skill://tdd`. Build through the agreed public-behavior seam in vertical red/green cycles. Accept user-reported failure evidence rather than rerunning merely to confirm it; seek causal evidence and exercise the changed behavior. Run relevant single test files and typechecking during implementation where applicable, then the required project checks and full test suite once at the end. Record exact outcomes, including checks unavailable in this environment. A failed or unrun required validation is not a pass.

Once done, load `code-review` through the same harness mechanism to review the actual change against the ticket/spec and project standards. Address supported findings, then run checks affected by those fixes. If a check or review blocks completion, report the blocker rather than marking the ticket done.

Commit only the intended work on the current branch through the existing signed-commit approval route and `git-conventions`. Do not stage unrelated changes or bypass signing, permissions, or host approval. If approval is declined or unavailable, retain the changes and report them as uncommitted. Apply ticket status/comment/closure updates only through the configured approval route and only when their completion criteria are actually met.

If durable progress is needed, use `.dev-skills/features/<slug>/progress.md`. Report implemented behavior, exercised checks, review outcome, actual commit status, and remaining blockers. Do not push or create a PR unless requested and approved.

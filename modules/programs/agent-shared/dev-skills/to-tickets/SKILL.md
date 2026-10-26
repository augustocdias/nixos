---
name: to-tickets
description: Break a plan, spec, or the current conversation into a set of tracer-bullet tickets, each declaring its blocking edges, published to the configured tracker (edges as text in one file per ticket locally, or native blocking links on a real tracker).
disable-model-invocation: true
---

[Shared workflow](WORKFLOW.md)

Resolve and retain the absolute `.dev-skills/` workspace path according to the shared workflow before reading configuration or writing supporting artifacts. Pass that absolute path to any subagents; a subprocess changing directory must not change artifact destinations. Paths below beginning with `.dev-skills/` mean that resolved workspace, not a new directory relative to the subprocess. Use the workspace configuration and domain-document references, preserving existing authoritative project documents.


# To Tickets

Break a plan, spec, or conversation into a set of **tickets**: tracer-bullet vertical slices, each declaring the tickets that **block** it.

Read `issue-tracker.md`, `triage-labels.md`, and `domain.md` in the resolved workspace. If required configuration is absent, suggest Claude `/setup-dev-skills` or omp `/skill:setup-dev-skills`; do not automatically invoke manual setup.

## Process

### 1. Gather context

Work from whatever is already in the conversation context. If the user passes a reference (a spec path, an issue number or URL) as an argument, fetch it and read its full body and comments.

### 2. Explore the codebase (optional)

If you have not already explored the codebase, do so to understand the current state of the code. Ticket titles and descriptions should use the project's domain glossary vocabulary, and respect ADRs in the area you're touching.

Look for necessary prefactoring that makes the agreed implementation easier. "Make the change easy, then make the easy change." Do not add unrelated cleanup or speculative abstraction.

### 3. Draft vertical slices

Break the work into **tracer bullet** tickets.

<vertical-slice-rules>

- Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests): vertical, NOT a horizontal slice of one layer
- A completed slice is demoable or verifiable on its own
- Each slice is sized to fit in a single fresh context window
- Any necessary agreed prefactoring should be done first

</vertical-slice-rules>

Give each ticket its **blocking edges**: the other tickets that must complete before it can start. A ticket with no blockers can start immediately.

**Wide refactors are the exception to vertical slicing.** A **wide refactor** is one mechanical change whose blast radius spans the codebase and cannot land as independent green vertical slices. Prefer a complete atomic cutover when feasible. Use temporary expand–migrate–contract steps only when explicitly agreed and needed to keep the migration safe, never as an automatic compatibility shim. If used, ticket the expansion, each migration batch blocked by expansion, and final deletion blocked by every batch. Include the complete removal of old forms and callers in the agreed work. If intermediate batches cannot stay green alone, describe that validation boundary explicitly and require final integrate-and-verify acceptance before the work is complete. Execute the sequence in the current checkout; do not create an integration branch, switch branches, or manage worktrees.

### 4. Quiz the user

Present the proposed breakdown as a numbered list. For each ticket, show:

- **Title**: short descriptive name
- **Blocked by**: which other tickets (if any) must complete first
- **What it delivers**: the end-to-end behaviour this ticket makes work

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the blocking edges correct: does each ticket only depend on tickets that genuinely gate it?
- Should any tickets be merged or split further?

Iterate until the user approves the breakdown.

### 5. Publish the tickets to the configured tracker

Publish the approved tickets through the configured mutation-approval route. **How** depends on the tracker setup configured; the tickets are the same either way, only the shape of the blocking edges changes:

- **Local files** → write one file per ticket under `.dev-skills/features/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01` in dependency order (blockers first). Each file's "Blocked by" lists the numbers/titles it depends on. Use the per-ticket file template below: one ticket per file, never a single combined file.
- **A real issue tracker (GitHub, Linear, …)** → publish one issue per ticket in dependency order (blockers first) so each ticket's blocking edges can reference real identifiers. Use the platform's native blocking relationship where it has one; otherwise set each ticket's "Blocked by" to the blocking issues. If the source was an existing issue, make each ticket its sub-issue (tracker doc's operation). Apply the actual mapped `ready-for-agent` role unless instructed otherwise; do not invent labels or create them without approval; the tickets are agent-grabbable by construction.

Remote publications must include the needed content or approved accessible attachments, not only local `.dev-skills/` links. For local tickets, include a relative reference to `../spec.md` when a specification exists, and keep dependency references resolvable.

Work the **frontier**: any ticket whose blockers are all done. For a purely linear chain that means top to bottom.

Do NOT close or modify any parent issue.

<local-ticket-template>

# <NN>: <Ticket title>

**What to build:** the end-to-end behaviour this ticket makes work, from the user's perspective, not a layer-by-layer implementation list.

**Blocked by:** the numbers/titles of the tickets that gate this one, or "None (can start immediately)".

**Status:** ready-for-agent

- [ ] Acceptance criterion 1
- [ ] Acceptance criterion 2

</local-ticket-template>

<issue-template>

## Parent

A reference to the parent issue on the tracker (if the source was an existing issue, otherwise omit this section).

## What to build

The end-to-end behaviour this ticket makes work, from the user's perspective, not layer-by-layer implementation.

## Acceptance criteria

- [ ] Criterion 1
- [ ] Criterion 2

## Blocked by

- A reference to each blocking ticket, or "None (can start immediately)". Omit this section when blockers were set as native edges.

</issue-template>

In either form, avoid specific file paths or code snippets: they go stale fast. Exception: if a prototype produced a snippet that encodes a decision more precisely than prose can (state machine, reducer, schema, type shape), inline it and note briefly that it came from a prototype. Trim to the decision-rich parts, not a working demo, just the important bits.

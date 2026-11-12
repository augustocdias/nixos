---
name: sdlc-review
description: Review a Kanban implementation, publish its approved PR, verify CI, and complete the card without waiting for merge.
version: 3.0.0
metadata:
  hermes:
    tags: [kanban, review]
    category: devops
    requires_toolsets: [kanban]
environments:
  - kanban
---

# Review through a code-review agent

Hermes's review lane loads a skill with this name into every reviewer run. This copy replaces the bundled one, which inspects code with a terminal the reviewer does not have. The review itself is the user's `code-review` skill, run by an agent you launch.

## First run on a card

1. `kanban_show`: read the header, ticket, full thread and latest handoff. Retain the exact checkout, branch, fixed base/head, check evidence, user decisions and ownership release. A branch with no PR is a valid review input.
2. `agent_launch` with skill `code-review`, the fixed base/head and the ticket as the spec. The card's `Agents:` line picks the harness. Keep this stage read-only and require separate Standards and Spec findings. For a stack, review only this layer against its approved predecessor, not against `main`.
3. Follow **Launch and park** in your role instructions. Confirm the agent is live and working before scheduling. Handle a report that already arrived instead of parking.

## Later run: the agent reported

The card returns to the review lane. Read the agent's `Done`, `Blocked` or `Question` comment.

- **Question**: answer from the ticket, thread or existing agreement with `agent_send`, then apply the startup check before parking. Escalate only an unresolved human decision or required approval.
- **Blocked**: distinguish an agent-fixable gap from a human prerequisite. Correctable code or check failures return to the programmer.
- **Done from code-review**: inspect both Standards and Spec. Blocking findings mean request changes. Otherwise continue to publication in this run; a review recommendation is not a reason to wait for the coordinator.
- **Done from publication**: verify the PR URL, base/head and required exact-head CI evidence, then record the verdict below.

## Publish after approval

When the Git agreement delegates PRs to agents, retain the review report, stop the finished review agent with `agent_kill`, then launch `pr` with the approved base/head, checkout, branch, absolute supporting workspace, review evidence, stack metadata and existing PR URL if any. `pr-ownership=agent` with `prs=gh stack` delegates publication through that stack tool. An unspecified owner is not authorization; `ask` and `human` ownership retain their normal routes. If human-owned publication prevents a required check from running, report the exact human action through the approval route and keep the card incomplete until the check passes.

The publication brief must require:

1. Verify the checkout and head still match the approved snapshot. A changed head returns to independent review before publication. Preserve exclusive checkout ownership between stages.
2. Load `git-conventions` and `pr`, use the existing agreement without asking again, and verify every outgoing commit signature before an authorized push. Publish only reviewed commits. For a stack, use the existing stack and predecessor base; inspect the submission scope so it cannot publish unreviewed layers or rewrite predecessors.
3. Find the PR by repository and head branch before creating one. Reuse its URL and update it in place. Preserve its identity, base and stack relationships. Never close/reopen or replace a PR to trigger CI. Merges, published rewrites and destructive actions still require their own authorization.
4. Observe required checks on the exact published head. Pending checks remain this stage's work, not a question for the user. For missing or failed runs, inspect the workflow trigger and logs first. Use a supported rerun or dispatch only when applicable and authorized. Never fabricate a pass or bypass a required check.
5. Report the PR URL, exact base/head, review result, required CI outcomes and ownership release. A code failure returns to the programmer with the failing run and diagnosis; the corrected head goes through independent review and updates this same PR. Non-required failures and user-owned manual checks are disclosed separately, not invented completion gates.

Follow **Launch and park** for this stage too. Preserve the existing PR when publication times out: inspect remote effects before retrying.

## Verdict

| Verdict | When | Final action |
|---|---|---|
| Approve | No blocking findings; required automated checks pass; delegated publication is verified | `kanban_complete` now with the approved head, PR and evidence |
| Request changes | Correctable findings or required CI failures | `kanban_comment` with evidence, then `kanban_request_changes` |
| Escalate | An unresolved human decision, required approval or prerequisite no agent can clear | `kanban_block` |

Board Done means agent work is approved and verified, not merged or deployed. Complete the card even when its PR is open and unmerged; this releases dependent cards to stack on its approved head. Keep external tracker closure subject to that tracker's policy, without making it a board dependency gate. Do not wait for another coordinator verdict or user comment.

Requested changes return the card to its implementer. Kill the reviewer agent with `agent_kill` after the verdict unless the coordinator asked to keep it. Never answer an agent's permission prompt.

---
name: sdlc-review
description: Route a Kanban review handoff to a launched reviewer agent running code-review, then record the verdict.
version: 2.0.0
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

1. `kanban_show`: the card header, the ticket in `Tracker:`, and the latest `review_requested` handoff with the implementer's branch, commits or PR and the checks it claims.
2. `agent_launch` with skill `code-review` and arguments naming the fixed point (the branch's merge-base, or the commit or PR) and the ticket as the spec. The card's `Agents:` line picks the harness.
3. `kanban_schedule` with reason `awaiting agent: <terminal>`. Stop.

## Later run: the agent reported

The card returns to the review lane. Read the agent's `Done`, `Blocked` or `Question` comment.

- **Question**: answer it from the ticket or card with `agent_send`, then park again. Otherwise escalate.
- **Blocked**: escalate.
- **Done**: the report has a Standards and a Spec section. Blocking findings in either mean changes.

## Verdict

| Verdict | When | Final action |
|---|---|---|
| Approve | No blocking findings; required checks pass | `kanban_complete` with the review summary |
| Request changes | Correctable findings | `kanban_comment` with the findings, then `kanban_request_changes` |
| Escalate | A human decision or an outside prerequisite | `kanban_block` |

Requested changes return the card to its implementer. Kill the reviewer agent with `agent_kill` after the verdict unless the coordinator asked to keep it. Never answer an agent's permission prompt.

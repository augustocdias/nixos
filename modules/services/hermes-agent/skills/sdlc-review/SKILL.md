---
name: sdlc-review
description: "Use when reviewing a Kanban card's implementation handoff, and after approval to publish authorized work and verify its CI."
version: 4.0.0
metadata:
  hermes:
    tags: [kanban, review]
    category: devops
    requires_toolsets: [kanban]
environments:
  - kanban
---

# Independent review

1. Read the card, ticket, full thread and latest handoff. Retain the exact checkout, branch, fixed base/head, check evidence and Git ownership. An uncommitted diff is a valid review input when commits belong to the user.
2. Load `code-review` and perform the review in this Hermes session. Keep review read-only and report Standards and Spec findings separately. Review stacked work against its approved predecessor, not automatically against main.
3. Return correctable findings with `kanban_comment` and `kanban_request_changes`. A revised head needs independent review again.

# Publication after approval

1. Verify that the checkout and reviewed head still match. Load `git-conventions` and `pr`, retaining the card's agent/human agreement. Publish only reviewed work.
2. Push through the Git proxy only when pushes are agent-owned. The proxy verifies every outgoing signature. If pushes or commits belong to the user, prepare a precise handoff instead of attempting them elsewhere.
3. When PRs are agent-owned and the head is published, find the PR by repository and branch before creating one. Update the existing PR in place. Preserve its base, identity and stack. Merges and published rewrites need separate authorization.
4. Observe required checks on the exact published head. Diagnose failures and return code fixes to programmer on the same branch. Pending checks remain work; user-owned manual checks remain explicitly unrun unless the user made them an acceptance gate.
5. Report `owner/repo#123`, exact base/head, review findings, required CI outcomes and any human handoff.

# Verdict

Complete with `kanban_complete` when agent-owned work meets every acceptance criterion and required checks pass. Use `kanban_request_changes` for correctable code or CI failures. Use `kanban_block` for a human prerequisite that prevents acceptance, including human publication needed for required CI. Human-owned actions that do not gate acceptance remain disclosed handoffs rather than invented blockers.

Release dependent cards after completion; external tracker closure follows its own policy.

---
name: sdlc-review
description: "Use when reviewing a Kanban card's implementation handoff, and after approval to publish the work and verify its CI."
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

1. Read the card, ticket, full thread and latest handoff. Retain the exact checkout, branch, fixed base/head and check evidence.
2. Load `code-review` and perform the review in this Hermes session. Keep review read-only and report Standards and Spec findings separately. Review stacked work against its approved predecessor, not automatically against main.
3. Return correctable findings with `kanban_comment` and `kanban_request_changes`. A revised head needs independent review again.

# Publication after approval

1. Verify that the checkout and reviewed head still match. Load `git` and `pr`. Publish only reviewed work.
2. Before pushing, confirm `git log --format='%H %G?' <remote-head>..<head>` prints `G` for every outgoing commit.
3. Once the head is published, find the PR by repository and branch before creating one. Update the existing PR in place. Preserve its base, identity and stack. Merges and published rewrites need separate authorization.
4. Observe required checks on the exact published head. Diagnose failures and return code fixes to programmer on the same branch. Pending checks remain work; user-owned manual checks remain explicitly unrun unless the user made them an acceptance gate.
5. Report in at most 120 words: `owner/repo#123`, exact base/head, findings, required CI outcomes and what the user must do, if anything.

# Verdict

Complete with `kanban_complete` when the work meets every acceptance criterion and required checks pass. Remove the card's worktree first, as `git` says; a failed removal gets its cleanup comment and never blocks completion. Use `kanban_request_changes` for correctable code or CI failures. Use `kanban_block` for a human prerequisite that prevents acceptance.

Release dependent cards after completion; external tracker closure follows its own policy.

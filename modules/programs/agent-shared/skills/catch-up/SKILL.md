---
name: catch-up
description: Summarize what changed since the user's last message and list every call waiting on them, decidable from the reply alone.
disable-model-invocation: true
---

[Shared workflow](WORKFLOW.md)

# Catch up

Catch the user up on what changed in this session since the last message they wrote before invoking this skill, and help them understand each change, not only where it stands. Then lay out every call waiting on them so they can make it from your reply alone. Notifications and subagent results are not their messages. Assume the user remembers their last message and nothing after it.

Write in plain words and short sentences, like one person catching up another. Say what changed for the user, not how you did it: "the tests pass", not "CI is green". Leave out hashes, file paths, commands, build numbers and test counts unless the user needs one to act. Call each PR, branch, ticket or agent by a name the user would know, not a label you invented. Give a fact its context or leave it out.

## Gather what changed

Keep this turn read-only: read state, build diagrams from what you already have, and change nothing else. Collect your own work since that message, reports from subagents and workers, and messages from anyone else in this session. Check the current state of each PR, CI run, ticket or worker this session touched. Check each number you will show against the facts it comes from, and say so when you correct one.

An action item is a call or step only the user can take: a product choice, an approval, an irreversible action, or access you lack. Include every one still waiting on the user, even one raised before their last message. Work you can still do yourself is not an action item. List only real calls. A step the user did not ask for and the work does not need is not an action item, unless it is irreversible and waiting on the user: give it one line.

One call can cover many items, such as each PR in a set awaiting merge. For each item, collect its link, what it changes for users, the evidence behind your pick, its risk, and your pick. Write "unknown" for a fact the call needs that you do not know. Leave out a link you do not have.

## Write the reply

Spend words on the calls, not on the story. Keep what happened under 100 words, not counting diagrams, and shorter when less happened. Leave out work that changed nothing for the user. Give each item about 30 words. The reply grows with the number of items; keep every item whole, as its own entry rather than a count or a bare link. A link can add depth, but the reply alone must be enough to decide.

1. Open with one short sentence that names what waits on the user, or says nothing does. If nothing happened and nothing waits, say so and stop.
2. Show what happened. Put any screenshot the work produced, then any Mermaid diagram that explains a change. Then sum up in one short bullet per thing the user asked for: what came of it, and whether it is done, still running, failed or not checked. Write each line the way you would say it out loud: "Search was slow from a missing index", not "Search review: done". Name any bug found and fixed on the way. Each line must stay true when read alone. Mark something done only when nothing about it waits on the user, and leave out anything the action items say. Under the summary, give at most three short lines that change what the user knows or must do. Then name in one line any work left that you can do yourself.
3. List the action items. Ask the call the user owns, such as merge, approve or pick, and give your pick. A step you would take first goes in your pick, as does anything that must happen first and anything that cannot be undone. Give the number or link of each PR, ticket or agent a call is about.

Fit the shape to the call:

- A call about one item is one bullet: the call, your pick, what it changes for users, the evidence behind your pick, and its risk, with the item named once.
- When items share a call, write the call and your pick once, then give each item its own bullet, riskiest first: its link and name, what it changes for users, the evidence behind your pick, and its risk. Name an item's pick only where it differs from the call's. Give each item's risk even when it is low, such as "Low risk: only the colors change." Say what waiting costs only when it is more than a delay, such as a deadline or lost data.
- For a call between options, give every option the work weighed, each with what it gets the user and what it costs, and the current state when there is one. Those costs are the call's risk.

## Diagrams

Draw a Mermaid diagram when something is easier to grasp as a picture than as sentences: how a design or system works, a PR stack or dependency chain with each PR's state, a before and after of a fix, or options side by side. Keep status lists and action items as text. A Markdown table is not a diagram.

Keep each diagram readable at a glance: at most six boxes, at most eight words in each, labels in words a person would say. Give each fact once, in text or in a diagram. Draw only from facts you have, and link only artifacts that exist.

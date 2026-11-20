---
name: blast-radius
description: "Use to find what a change could break outside its diff before it ships: \"blast radius of X\", \"what could this break\", a small diff you don't trust, or a change to a contract other code consumes."
---

[Shared workflow](WORKFLOW.md)

# Blast radius

Find what a change breaks somewhere else, before it ships. Listing the callers is not the job: grep does that in a second. The job is the breakage grep won't show you.

## Prove, don't assert

A writeup that sounds right reads as convincing whether or not it is true. Find the one or two facts the change's safety depends on and prove them by running code.

For each such fact, get it as far down this list as is cheap, and say where it stopped:

1. You said so. Worthless on its own.
2. You pointed at the line: a real `file:line`, or the dependency's own source.
3. You showed the bad case can't happen by walking the failure step by step until it fails to reach.
4. You ran it: a script or test that calls the real code and fails loudly if you are wrong.
5. You reproduced it in the running system.

Step 4 is usually one small script that imports the same library the project ships and calls the exact function you are worried about.

## Steps

1. **Read the change.** The diff, the symbols it adds, changes and deletes, and what it now does differently, including the part the diff doesn't spell out. Read the commits or PR when there is one.
2. **Find the safety fact.** Most changes that look risky are safe because of a single fact, such as "this call only drops cache entries that are already dead". If that fact holds, most risky cases clear at once. Spend your time here, not on a long list of maybes.
3. **Look where grep stops.** Read the source of the dependency you call, and check its pinned version and any local patch. Work out when things run: startup and teardown order, async scheduling, retries, lazy evaluation. Follow what a symbol search misses: a serialized format another program reads, a database column, a wire protocol, another language reading the same bytes, a feature flag, a config key, a generated file, code three hops downstream.
4. **Weigh each risk honestly.** Give it a real chance of happening and a real cost if it does. Keep the risks you confirmed and list the ones you checked and cleared separately. Cite a real `file:line`; a search that finds nothing is still an answer. Name only callers and APIs you found.
5. **Prove the safety fact.** Write a script or test that runs the real code, run it, and paste what happened. Keep proof scripts under `<absolute-workspace>/debug/<slug>/`. Run only local, read-only or disposable things; a fact that needs an external system becomes an open question in the report.
6. **Widen for a wide change.** When the change spans many consumers, the `code-review` Proof axis's extra adversaries cover the rest.

## Report

- **What it does.** What changed, including the part that isn't obvious.
- **The safety fact.** State it, say which level of the list above you reached, and show the proof. If you could not prove it, write "unproven".
- **Risks.** Each names how it breaks, the `file:line`, how likely and how bad, and how to check. Paste the proof for the ones that matter.
- **Cleared.** What you checked and why it is fine.
- **Before you merge.** The cheapest test or repro that catches the real bug, including the script you wrote.

When the result feeds a PR, the `pr` skill's Merge Danger "Blast Radius" field cites the safety fact and its proof level. Write the report by the `unslop` skill and keep private context out of anything public.

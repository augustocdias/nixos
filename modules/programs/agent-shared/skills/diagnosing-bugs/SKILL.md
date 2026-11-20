---
name: diagnosing-bugs
description: "Use when something is broken, throwing, failing or slow and the cause is unknown, including hard bugs, performance regressions and \"diagnose\" or \"debug this\" requests."
---

[Shared workflow](WORKFLOW.md)


# Diagnosing Bugs

A discipline for hard bugs. Skip phases only when explicitly justified.

This skill diagnoses. It ends with a cited diagnosis and a proposed fix, and it changes no production code. Phase 6 hands the diagnosis to whoever owns the fix.

Read `domain.md` in the resolved absolute workspace for authoritative glossary and ADR locations. New domain notes belong under that workspace, not tracked source directories. When exploring the codebase, read the configured `GLOSSARY.md` (if it exists) to get a clear mental model of the relevant modules, and check ADRs in the area you're touching.

## Evidence, permissions, and workspace

Accept the user’s reported failure and supplied output as ground truth. Do not rerun it merely to confirm the report. New probes must seek causal evidence or verify a fix, use one variable at a time, and respect the existing production/read-only permission boundary. If the reported failure already establishes a phase’s evidence, carry it forward rather than repeating it. Record any inaccessible causal check honestly.

Place generated scripts, minimized fixtures, redacted traces, profiles, and retained evidence under `<absolute-workspace>/debug/<slug>/`. Run diagnostic subprocesses with explicit absolute input/output paths so changing cwd does not relocate evidence. The proposed regression test names the agreed project seam where it belongs.

Before branch switching, bisection, or worktree use, load `git-conventions` and establish the upfront ownership agreement. Use an authorized diagnostic checkout; preserve user changes and unrelated worktrees. Headless workers return approval-dependent Git and remote actions to the parent rather than attempting host prompts. Keep supporting evidence local and outside production commits.

## Redact

This skill has you show commands, outputs and captured artifacts. **Redact every secret first**: write `<REDACTED>` in its place. Build loops against env vars, so the credential stays in the environment rather than in what you show. Captured artifacts carry auth headers: quote only the lines that carry the signal.

If the redacted output is not enough to diagnose the bug, say so and ask the user.

## Phase 1: Build a feedback loop

**This is the skill.** Everything else is mechanical. If you have a **tight** pass/fail signal for the bug (one that goes red on _this_ bug), you will find the cause; bisection, hypothesis-testing, and instrumentation all just consume it. If you don't have one, no amount of staring at code will save you.

Spend disproportionate effort here. **Be aggressive. Be creative. Refuse to give up.**

### Ways to construct one, in roughly this order

1. **Failing test** at whatever seam reaches the bug: unit, integration, e2e.
2. **Curl / HTTP script** against a running dev server.
3. **CLI invocation** with a fixture input, diffing stdout against a known-good snapshot.
4. **Headless browser script** (Playwright / Puppeteer) that drives the UI and asserts on DOM/console/network.
5. **Replay a captured trace.** Save a real network request / payload / event log to disk; replay it through the code path in isolation.
6. **Throwaway harness.** Spin up a minimal subset of the system (one service, mocked deps) that exercises the bug code path with a single function call.
7. **Property / fuzz loop.** If the bug is "sometimes wrong output", run 1000 random inputs and look for the failure mode.
8. **Bisection harness.** If the bug appeared between two known states (commit, dataset, version), automate "boot at state X, check, repeat" so you can `git bisect run` it. Use the agreed diagnostic checkout/worktree and absolute debug paths. Preserve the initial ref, narrow the first bad state with the tight causal loop, then leave the checkout at its agreed final ref without discarding user work. If ownership or historical inputs are unavailable, report the missing action and use immutable-state comparisons where possible.
9. **Differential loop.** Run the same input through old-version vs new-version (or two configs) and diff outputs.
10. **HITL bash script.** Last resort. If a human must click, drive _them_ with `scripts/hitl-loop.template.sh` so the loop is still structured. Captured output feeds back to you.

Build the right feedback loop, and the bug is 90% fixed.

### Tighten the loop

Treat the loop as a product. Once you have _a_ loop, **tighten** it:

- Can I make it faster? (Cache setup, skip unrelated init, narrow the test scope.)
- Can I make the signal sharper? (Assert on the specific symptom, not "didn't crash".)
- Can I make it more deterministic? (Pin time, seed RNG, isolate filesystem, freeze network.)

A 30-second flaky loop is barely better than no loop; a 2-second deterministic one is tight, a debugging superpower.

### Non-deterministic bugs

The goal is not a clean repro but a **higher reproduction rate**. Loop the trigger 100×, parallelise, add stress, narrow timing windows, inject sleeps. A 50%-flake bug is debuggable; 1% is not, so keep raising the rate until it's debuggable.

### When you genuinely cannot build a loop

Stop and say so explicitly. List what you tried. Ask the user for: (a) access to whatever environment reproduces it, (b) a redacted captured artifact (HAR file, log dump, core dump, screen recording with timestamps), or (c) permission to add temporary production instrumentation. Do **not** proceed to hypothesise without a loop.

### Completion criterion: a tight loop that goes red

Phase 1 is done when the loop is **tight** and **red-capable**: you can name **one command** (a script path, a test invocation, a curl) that you have **already run at least once** (show the invocation and its output, redacted), or use the user’s supplied invocation and output when they already establish the failure. Any newly run command must seek additional causal evidence, not reconfirm their report. The loop is:

- [ ] **Red-capable**: it drives the actual bug code path and asserts the **user's exact symptom**, so it can go red on this bug and green once fixed. Not "runs without erroring"; it must be able to _catch this specific bug_.
- [ ] **Deterministic**: same verdict every run (flaky bugs: a pinned, high reproduction rate, per above).
- [ ] **Fast**: seconds, not minutes.
- [ ] **Agent-runnable**: you can run it unattended; a human in the loop only via `scripts/hitl-loop.template.sh`.

If you catch yourself reading code to build a theory before this command exists, **stop: jumping straight to a hypothesis is the exact failure this skill prevents.** No red-capable command, no Phase 2.

## Phase 2: Reproduce + minimise

Use the accepted failing evidence. Run the loop only when the new run gathers causal evidence or supports minimization, not merely to prove the reported failure.

Confirm:

- [ ] The loop produces the failure mode the **user** described, not a different failure that happens to be nearby. Wrong bug = wrong fix.
- [ ] The failure is reproducible across multiple runs (or, for non-deterministic bugs, reproducible at a high enough rate to debug against).
- [ ] You have captured the exact symptom (error message, wrong output, slow timing) so later phases can verify the fix actually addresses it.

### Minimise

Once it's red, shrink the repro to the **smallest scenario that still goes red**. Cut inputs, callers, config, data, and steps **one at a time**, re-running the loop after each cut, and keep only what's load-bearing for the failure.

Why bother: a minimal repro shrinks the hypothesis space in Phase 3 (fewer moving parts left to suspect) and becomes the proposed regression test in Phase 5.

Done when **every remaining element is load-bearing**: removing any one of them makes the loop go green.

Do not proceed until you have reproduced **and** minimised.

## Phase 3: Hypothesise

Generate **3–5 ranked hypotheses** before testing any of them. Single-hypothesis generation anchors on the first plausible idea. Seed them with the change history of the affected code: the commits and PR discussions that introduced or last changed it, read through the Rationale mode of `research`.

Each hypothesis must be **falsifiable**: state the prediction it makes.

> Format: "If <X> is the cause, then <changing Y> will make the bug disappear / <changing Z> will make it worse."

If you cannot state the prediction, the hypothesis is a vibe: discard or sharpen it.

**Show the ranked list to the user before testing.** They often have domain knowledge that re-ranks instantly ("we just deployed a change to #3"), or know hypotheses they've already ruled out. Cheap checkpoint, big time saver. Don't block on it; proceed with your ranking if the user is AFK.

## Phase 4: Instrument

Each probe must map to a specific prediction from Phase 3. **Change one variable at a time.**

Tool preference:

1. **Debugger / REPL inspection** if the env supports it. One breakpoint beats ten logs.
2. **Targeted logs** at the boundaries that distinguish hypotheses.
3. Never "log everything and grep".

**Tag every debug log** with a unique prefix, e.g. `[DEBUG-a4f2]`. Cleanup at the end becomes a single grep. Untagged logs survive; tagged logs die.

**Perf branch.** For performance regressions, logs are usually wrong. Instead: establish a baseline measurement (timing harness, `performance.now()`, profiler, query plan), then bisect using the agreed diagnostic checkout and one controlled input at a time. Vet every number with `benchmark-checklist` before you trust it.

**Premise check.** When two refuted hypotheses, or two failed fix attempts reported to you, share one assumption, suspect the assumption. Write it as one sentence and name an observation that would come out differently if it were false. Make that observation when it is within reach: a local run, a log, a read-only query. When it needs another system, access you lack, or a person, record it as an open question in the diagnosis and ask for that evidence. Build no further hypothesis on the assumption until the observation answers it.

## Phase 5: Diagnosis and proposed fix

Write the diagnosis to `<absolute-workspace>/debug/<slug>/diagnosis.md`. It contains:

- **Cause.** The confirmed mechanism, the evidence that confirmed it, and the hypotheses that the evidence ruled out.
- **Repro.** The minimised Phase 1 command and its redacted output.
- **Proposed fix.** The smallest change that fixes the root cause, and where it goes. Ask whether the state that triggered the symptom is legitimate. If it is, the fix handles that state where the code broke. If the state should never exist, the fix goes where the state was produced, because a guard at the symptom hides the bug. Name every other place with the same fault.
- **Regression test.** The **correct seam** for a test that goes red on this bug: one where the test exercises the real bug pattern as it occurs at the call site. If the only available seam is too shallow (a single-caller test when the bug needs several callers, a unit test that cannot replicate the triggering chain), say so. A missing seam is itself a finding: the architecture prevents locking the bug down.
- **Signal.** When finding the cause took a deep dig, propose the cheap always-on signal (a log line, a metric, an assertion) that would have shown it at first look.
- **Open questions.** Premise checks and evidence that need another system, access or a person.

## Phase 6: Hand off

- **Inside another workflow** (an assigned ticket, card or orchestrated task): return the diagnosis to that workflow. When the fix lies inside the assignment's scope, the assigned workflow owns it and applies it with its own tests and review. When the fix lies outside that scope, the assignment reports a blocker that carries the diagnosis, so the user decides whether a ticket or card follows.
- **Invoked directly**: turn the diagnosis into a plan the user can act on. Write `<absolute-workspace>/debug/<slug>/plan.md` with the sections of a `to-spec` specification: Problem Statement, Solution, Implementation Decisions, Testing Decisions (the regression seam goes here), Out of Scope and Further Notes (the open questions go here). Then suggest `to-spec` to publish it, or `to-tickets` when the fix needs several tickets.

## Phase 7: Cleanup

Required before declaring done:

- [ ] The diagnosis and, when invoked directly, the plan exist at their workspace paths
- [ ] All `[DEBUG-...]` instrumentation removed (`grep` the prefix)
- [ ] Throwaway diagnostic scaffolds deleted; retain only useful redacted evidence under `<absolute-workspace>/debug/<slug>/`
- [ ] The checkout is back at its agreed ref with no production change left behind

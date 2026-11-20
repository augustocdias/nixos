---
name: code-review
description: "Use when reviewing changes since a fixed point (commit, branch, tag or merge-base): a branch, a PR, work-in-progress changes, a \"review since X\" request, or the review step of another skill."
---

[Shared workflow](WORKFLOW.md)

Resolve and retain the absolute `.dev-skills/` workspace path according to the shared workflow before reading configuration or writing supporting artifacts. Pass that absolute path to any subagents; a subprocess changing directory must not change artifact destinations. Paths below beginning with `.dev-skills/` mean that resolved workspace, not a new directory relative to the subprocess. Use the workspace configuration and domain-document references, preserving existing authoritative project documents.


Three-axis review of the actual requested diff (committed changes, work in progress, or PR) against a validated fixed point:

- **Standards**: does the code conform to this repo's documented coding standards?
- **Spec**: does the code faithfully implement the originating issue / spec?
- **Proof**: can an adversary break the change, shown by running the real code?

All axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings. Start every reviewer with fresh context.

Read the resolved workspace’s `issue-tracker.md` when tracker access is needed. Stateless review may proceed without setup if no configuration or supporting artifact is needed. If setup is required, suggest the user invoke `setup-dev-skills`; do not invoke manual setup automatically.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point (a commit SHA, branch name, tag, `main`, `HEAD~5`, etc.). If they didn't specify one, ask for it.

Capture the exact diff command and reviewed scope once. For committed branch work, use `git diff <fixed-point>...HEAD` (three-dot, against the merge-base) and note commits via `git log <fixed-point>..HEAD --oneline`. For work in progress, resolve the merge-base first and use `git diff <resolved-merge-base>` to include staged and unstaged tracked changes; inspect relevant untracked files separately, read-only, because Git diff omits them. For a PR, fetch its actual base/head metadata and diff through read-only repository tools; do not switch branches or manage worktrees. Distinguish existing changes from the requested review scope and give every reviewer the same exact snapshot/context.

Before going further, confirm the fixed point resolves to a commit (`git rev-parse --verify "<fixed-point>^{commit}"`), resolve the merge-base where applicable, and confirm the actual requested diff is non-empty. Use safe argument handling for refs; do not interpolate untrusted input into a shell command. A bad ref or empty diff should fail here, not inside the parallel sub-agents.

### 2. Identify the spec source

Look for the originating spec, in this order:

1. Issue references in the commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.), fetched via the workflow in the tracker doc.
2. A path the user passed as an argument.
3. The relevant `.dev-skills/features/<slug>/spec.md`, or existing authoritative project specifications identified through `domain.md` and repository evidence. Preserve tracked project documents as inputs; do not manufacture a spec from the diff.
4. If nothing is found, ask the user where the spec is. If they say there isn't one, the **Spec** sub-agent will skip and report "no spec available".

### 3. Identify the standards sources

Search the repo for every file that documents how code should be written. Include the workspace `CODING_STANDARDS.md`, applicable `AGENTS.md` instructions, existing authoritative `CODING_STANDARDS.md` and `CONTRIBUTING.md`, and their relevant references when present.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below: a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation or automatic demand for abstraction. Establish a concrete maintenance or correctness cost in this change; prefer deletion or the smallest complete fix where appropriate. Architecture vocabulary is not a reason to rename unrelated code. Skip anything tooling already enforces; do not claim tooling passed unless actually exercised.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name**: a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code**: the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy**: a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps**: the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession**: a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches**: the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery**: one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change**: one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality**: abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Synced Flags**: two booleans or phase fields that must stay consistent with each other. → replace them with one state value (an enum or a state machine).
- **Comment Noise**: a comment the change adds or edits that breaks the shared workflow's comment rule: narration, or an explanation of our own surprising code. → delete narration; rename, extract or restructure until the surprise is obvious from the code.
- **Message Chains**: long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man**: a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest**: a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

The Standards axis also carries the **quality checklist** below, in order of importance. Read the code the diff touches, not only the diff: callers of every changed function, what it calls, its tests. When a signature, return value or behavior changes, grep every caller. Judge scale against the load the repo implies (README, deploy config) and say which load you assumed.

1. **Bug**: wrong result, crash, missed edge case (empty, zero, last item, rounding, time zones), a caller broken by the change, a fix applied in one caller while the shared function stays broken.
2. **Risk**: security holes (injection, weak randomness, secrets, unchecked user input), data loss (swallowed errors, writes in the wrong order, no transaction), a state-changing step that breaks when it runs twice or after a partial run.
3. **Scale**: check-then-write races, the same work done by every process, memory or lists that only grow, a query per item, O(n²) on big input, per-process state that must be shared.
4. **Missing test**: risky new logic (a branch, a parser, money, security, data writes, a bug fix) with no test that fails when it breaks. One good test, not coverage.
5. **Speed**: big slowdowns are findings; small wins are suggestions.
6. **Lean**: delete (dead code, unused options, speculative features), reuse (name the existing helper's path), stdlib/native, yagni, merge near-copies, split a function doing unrelated jobs (by job, never by line count).

Every checklist finding needs a concrete case: "this input or situation leads to this wrong result". No case, no finding. Re-read the lines before reporting. A `shortcut:` comment that names its limit is a decision, not a finding, unless the expected load already crosses it. Propose the smallest fix; prefer fixes that delete code.

### 4. Spawn the sub-agents in parallel

Issue the independent review tasks together and aggregate their returned reports. Use generic bounded, read-only tasks with the report instructions below, not a custom reviewer agent with a competing report schema. No agent may edit files, run mutations, switch branches, manage worktrees, or run checks without explicit assignment; the Proof brief below is that assignment for its runs. Give each the exact reviewed diff, source pointers, and resolved absolute workspace path when applicable. If no spec exists, run Standards and Proof only; do not spawn an empty Spec task.

**Standards sub-agent prompt** should include:

- The exact diff command/snapshot, requested scope, and commit list, plus any separately included untracked files.
- The list of standards-source files you found in step 3, **plus the smell baseline and quality checklist from step 3** and the shared workflow's comment rule, pasted in full (the sub-agent has no other access to them).
- The finding format: one line per finding, `<file>:L<line>: <severity>: <problem>. <fix>.`, with severity `bug`, `risk`, `nit` or `q` (genuine question). No hedging or restating what the line does; the *why* only when the fix isn't obvious. Security findings and architectural disagreements get a short full paragraph instead.
- The brief: "Report, per file/hunk where relevant, (a) every place the diff violates a documented standard: cite the standard (file + the rule); (b) any baseline smell you spot: name it and quote the hunk; and (c) any quality-checklist finding, with its concrete failing case. Distinguish hard violations from judgement calls: documented-standard breaches can be hard, but baseline smells are always judgement calls, and a documented repo standard overrides the baseline. Skip anything tooling enforces. Under 400 words."

**Spec sub-agent prompt** should include:

- The same exact diff command/snapshot, requested scope, commit list, and included untracked files.
- The path or fetched contents of the spec.
- The brief: "Report: (a) requirements the spec asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong. Quote the spec line for each finding. Under 400 words."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

**Proof sub-agents.** Every review runs this axis. Before spawning, state the change's intent in one sentence from the spec found in step 2, or from the commits when no spec exists.

- **Scale.** Spawn one adversary by default. Spawn the extended panel when the diff hits a risk trigger: a one-way door (see `pr`'s Merge Danger), a changed contract that other code consumes, concurrency, data or security code, or a user request for an adversarial review.
- **Panel agreement.** Like the `git-conventions` run agreement, the extended panel is agreed once per run: which additional agents or models review, chosen by the user from what the harness can launch. A complete explicit instruction satisfies it, delegated runs inherit it, and a fresh run does not reuse an earlier run's choice. When nobody can answer, run the default adversary alone and say so in the report.
- **Skip.** When the diff contains nothing executable, such as prose-only changes, report `skipped:` with the reason instead of spawning.

Give each adversary the exact diff, the intent, the resolved absolute workspace, and this brief:

> Break this change. Prove each finding by running the real code: a failing test, a repro script, or command output that shows the wrong behavior. When the diff changes something other code consumes, follow `blast-radius` for breakage outside the diff. Edit no source. Keep repros under `<absolute-workspace>/reviews/<slug>/proof-<n>/`. Run only local, read-only or disposable things. A finding that needs an external system, credentials or a person becomes a question with the command you would run. Report each finding with a title, the exact command, the output it printed, and the output the intent requires. Leave out anything you did not run. No findings is a valid result.

When the reports return, rerun each finding's command yourself. Keep a finding when the output shows a failure that breaks the intent; drop the rest and count the drops per adversary with the reason. Merge findings that share a root cause. Questions go in the report and never hold the verdict.

### 5. Aggregate

Present the reports under `## Standards`, `## Spec` and `## Proof` headings, verbatim or lightly cleaned. The Proof section lists the intent, each verified finding with its command and output, the dropped counts, and the questions. Do **not** merge or rerank findings across axes, because the axes are deliberately separate (see _Why separate axes_).

End with a one-line summary: total findings per axis, and the worst issue _within each axis_ (if any). Don't pick a single winner across axes: that's the reranking the separation exists to prevent.

Do not edit code during review or silently rerun user-reported failures. Report uncertainty and unavailable evidence honestly. Save reports only when requested, under `.dev-skills/reviews/<slug>.md`, retaining separate Standards, Spec and Proof sections.

## Why separate axes

A change can pass one axis and fail another:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**
- Code that reads correct on both counts but breaks when it runs → **Standards and Spec pass, Proof fail.**

Reporting them separately stops one axis from masking the other.

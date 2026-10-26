---
name: code-review
description: "Review the changes since a fixed point (commit, branch, tag, or merge-base) along two axes: Standards (does the code follow this repo's documented coding standards?) and Spec (does the code match what the originating issue/spec asked for?). Runs both reviews in parallel sub-agents and reports them side by side. Use when the user wants to review a branch, a PR, work-in-progress changes, or asks to \"review since X\"."
---

[Shared workflow](WORKFLOW.md)

Resolve and retain the absolute `.dev-skills/` workspace path according to the shared workflow before reading configuration or writing supporting artifacts. Pass that absolute path to any subagents; a subprocess changing directory must not change artifact destinations. Paths below beginning with `.dev-skills/` mean that resolved workspace, not a new directory relative to the subprocess. Use the workspace configuration and domain-document references, preserving existing authoritative project documents.


Two-axis review of the actual requested diff (committed changes, work in progress, or PR) against a validated fixed point:

- **Standards**: does the code conform to this repo's documented coding standards?
- **Spec**: does the code faithfully implement the originating issue / spec?

Both axes run as **parallel sub-agents** so they don't pollute each other's context, then this skill aggregates their findings.

Read the resolved workspace’s `issue-tracker.md` when tracker access is needed. Stateless review may proceed without setup if no configuration or supporting artifact is needed. If setup is required, suggest Claude `/setup-dev-skills` or omp `/skill:setup-dev-skills` manually; do not invoke manual setup automatically.

## Process

### 1. Pin the fixed point

Whatever the user said is the fixed point (a commit SHA, branch name, tag, `main`, `HEAD~5`, etc.). If they didn't specify one, ask for it.

Capture the exact diff command and reviewed scope once. For committed branch work, use `git diff <fixed-point>...HEAD` (three-dot, against the merge-base) and note commits via `git log <fixed-point>..HEAD --oneline`. For work in progress, resolve the merge-base first and use `git diff <resolved-merge-base>` to include staged and unstaged tracked changes; inspect relevant untracked files separately, read-only, because Git diff omits them. For a PR, fetch its actual base/head metadata and diff through read-only repository tools; do not switch branches or manage worktrees. Distinguish existing changes from the requested review scope and give both reviewers the same exact snapshot/context.

Before going further, confirm the fixed point resolves to a commit (`git rev-parse --verify "<fixed-point>^{commit}"`), resolve the merge-base where applicable, and confirm the actual requested diff is non-empty. Use safe argument handling for refs; do not interpolate untrusted input into a shell command. A bad ref or empty diff should fail here, not inside two parallel sub-agents.

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
- **Message Chains**: long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man**: a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest**: a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

### 4. Spawn both sub-agents in parallel

When a specification exists, issue both independent review tasks together and aggregate their returned reports. Use generic bounded, read-only tasks with the report instructions below, not a custom reviewer agent with a competing report schema. No agent may edit files, run mutations, switch branches, manage worktrees, or run checks without explicit assignment. Give each the exact reviewed diff, source pointers, and resolved absolute workspace path when applicable. If no spec exists, run only Standards; do not spawn an empty Spec task.

**Standards sub-agent prompt** should include:

- The exact diff command/snapshot, requested scope, and commit list, plus any separately included untracked files.
- The list of standards-source files you found in step 3, **plus the smell baseline from step 3** pasted in full (the sub-agent has no other access to it).
- The brief: "Report, per file/hunk where relevant, (a) every place the diff violates a documented standard: cite the standard (file + the rule); and (b) any baseline smell you spot: name it and quote the hunk. Distinguish hard violations from judgement calls: documented-standard breaches can be hard, but baseline smells are always judgement calls, and a documented repo standard overrides the baseline. Skip anything tooling enforces. Under 400 words."

**Spec sub-agent prompt** should include:

- The same exact diff command/snapshot, requested scope, commit list, and included untracked files.
- The path or fetched contents of the spec.
- The brief: "Report: (a) requirements the spec asked for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong. Quote the spec line for each finding. Under 400 words."

If the spec is missing, skip the Spec sub-agent and note this in the final report.

### 5. Aggregate

Present the two reports under `## Standards` and `## Spec` headings, verbatim or lightly cleaned. Do **not** merge or rerank findings, because the two axes are deliberately separate (see _Why two axes_).

End with a one-line summary: total findings per axis, and the worst issue _within each axis_ (if any). Don't pick a single winner across axes: that's the reranking the separation exists to prevent.

Do not edit code during review or silently rerun user-reported failures. Report uncertainty and unavailable evidence honestly. Save reports only when requested, under `.dev-skills/reviews/<slug>.md`, retaining separate Standards and Spec sections.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the issue asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.

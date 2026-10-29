---
name: prototype
description: Build a throwaway prototype to answer a design question. Use when the user wants to sanity-check whether a state model or logic feels right, or explore what a UI should look like.
---

[Shared workflow](WORKFLOW.md)


# Prototype

A prototype is **throwaway code that answers a question**. The question decides the shape.

## Pick a workflow

Identify which question is being answered, using the user's prompt, the surrounding code, or by asking if the user is around:

- **"Does this logic / state model feel right?"** → [LOGIC.md](LOGIC.md). Build a single shareable HTML file (free-play buttons plus tabbed guided walkthroughs) that pushes the state machine through cases that are hard to reason about on paper, and that a non-developer can drive.
- **"What should this look like?"** → [UI.md](UI.md). Generate several radically different UI variations on a single route, switchable via a URL search param and a floating bottom bar.

The two branches produce very different artifacts, so getting this wrong wastes the whole prototype. If the question is genuinely ambiguous and the user isn't reachable, default to whichever branch better matches the surrounding code (a backend module → logic; a page or component → UI) and state the assumption at the top of the prototype.

Before checkout/worktree changes or Git publication, load `git-conventions` through Claude's native Skill mechanism or omp's `read skill://git-conventions` and establish ownership. Headless workers request privileged or remote actions from the parent. Prototype selection can be promoted within the user's requested implementation scope; if the request is exploration-only, capture the decision and hand off the production change.

## Rules that apply to both

1. **Throwaway from day one, and clearly marked as such.** Keep prototype source, variants, dependencies, build outputs, scratch data, reports, and primary-source captures under `<absolute-workspace>/prototypes/<slug>/`. Reference the intended production location. Temporary route imports, rendering switches, or task-runner wiring may run in an authorized development checkout using the project's existing conventions. Record that wiring and remove it before implementation commits; retain any useful capture only in the workspace.
2. **Trivial to run.** A UI prototype starts with one command using the project's task runner and an explicit checkout, or absolute paths to its workspace preview. A logic demo is a single HTML file the user double-clicks. Anchor generated outputs to the prototype directory, regardless of caller cwd.
3. **No persistence by default.** State lives in memory. Persistence is the thing the prototype is _checking_, not something it should depend on. If the question explicitly involves a database, hit a scratch DB or a local file with a clear "PROTOTYPE, wipe me" name.
4. **Skip the polish.** No tests, no error handling beyond what makes the prototype _runnable_, no abstractions. The point is to learn something fast.
5. **Surface the state.** After every action (logic) or on every variant switch (UI), print or render the full relevant state so the user can see what changed.
6. **Capture it when done.** Fold the validated decision into real code within the requested implementation scope, with normal production tests, error handling, and review. Keep the complete prototype as a **primary source** in its workspace directory, not an artifact branch. Write `result.md` beside it with the question, variants or guided cases, observed results, limitations, user selection, and verdict. Give the user the absolute path; remote issues receive only an authorized concise verdict or separately requested sharing. Remove experimental wiring before commits. Stage only the selected production change, its tests, and task-required production documentation, never prototype artifacts.

## Verify the actual preview

Open the generated HTML or preview in a real browser. Exercise guided cases and free-play for LOGIC, and every variant, URL selection, keyboard control, and switcher for UI. Report actual observations; disclose unavailable browser access rather than claiming the preview works.

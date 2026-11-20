---
name: create-verification-skill
description: Generate a project-local skill that drives the real app the way a user does and proves behavior.
disable-model-invocation: true
---

[Shared workflow](WORKFLOW.md)

# Create a verification skill

Every serious project needs a scripted way to drive the real app and prove behavior: launch it, exercise a feature the way a user would, and capture evidence. This skill generates that as a project-local skill at `<git-root>/.dev-skills/skills/verify-<app>/`, the folder where this project's personal skills live. Write it for the next agent, not for a human: it will be read cold, mid-task, by an agent that has never seen the app.

## 1. Interview the repo, not the user

Answer these from the codebase, and ask the user only what you cannot observe:

- **Surface:** what does a user actually touch? A web UI, a CLI or TUI, a desktop app, an API, a mobile app, a library? A repo can have several; pick the primary one and note the rest.
- **Run:** how does the app start locally? Prefer the repo's own documented dev command (package scripts, Makefile, README quickstart). Note ports, env vars, seed data and auth.
- **Drive:** how can an agent interact with it programmatically? Existing harnesses first: Playwright or Cypress specs, expect scripts, PTY helpers, curl-able endpoints, a debug port. Only then pick a generic recipe: the `terminal-browser` skill for web UIs, a tmux or PTY session for CLI and TUI, plain HTTP for services.
- **Observe:** what evidence can be captured? Screenshots, terminal transcripts, response bodies, logs, exit codes, database state.
- **Isolate:** can two instances run side by side (ports, data dirs, profiles)? If not, say so in the generated skill, so agents refuse to double-drive a shared instance instead of corrupting the user's session.

If the checkout doesn't build or start as-is, fix that first or report it precisely before generating; a skill written against a broken base teaches wrong steps. When an irrelevant missing asset blocks startup (a static dir the API never serves, a sample config), the generated skill may create it, clearly marked as verification scaffolding, and remove it in cleanup.

## 2. Generate the skill

Write `<git-root>/.dev-skills/skills/verify-<app>/SKILL.md` with frontmatter (`name: verify-<app>` and a `description` that names the app, the surface and when to reach for it; without frontmatter the skill never registers) and these sections, each grounded in what the interview found, with no placeholders left:

- **Launch:** the exact command that starts the app for verification, and how to tell it's ready (a log line, a prompt). Launch must reach a usable state from an empty data dir, including migrations and seed data. Ready means usable, not just that a process answers: a database health check can pass while its init scripts still run. Include teardown. For a short-lived CLI or TUI there is no server to keep alive: launch means build the binary or install deps once, then start each drive in its own isolated PTY or tmux session.
- **Doctor:** one read-only check that answers "is this instance worth driving?": process up, right version or build, port owned by this run, auth valid. An agent runs it first whenever anything looks off.
- **Drive:** the harness recipe with real selectors and commands from this repo, not examples. Prefer stable handles (ARIA labels, data attributes, prompt strings, route paths) over coordinates and tab order.
- **Evidence:** what to capture for a proof and where it goes. State the proof standards: exercise the real user path, not internal setters or test-only endpoints; capture the action and the resulting state, not just the final screen; verify side effects (files written, rows inserted, messages sent) alongside what is visible; use mocks only where a production boundary already isolates the external system. When the safe path is a dry-run or test mode, verify what it actually skips by observing files, network and git refs rather than trusting its name.
- **Cleanup:** how to tear down instances the run created. Kill only what you started, by its recorded identity, never by process name. Cleanup removes instances and scratch state and keeps the evidence: proof artifacts survive teardown, in a location the skill names under `<absolute-workspace>/debug/`.
- **Helpers:** any script the skill ships is executable, and its invocation is shown in the skill body.

## 3. Seed the feature map

Create `verify-<app>/features/README.md` plus one file per user-facing feature you can identify (the top 3 to 5 to start, from routes, commands, menus or docs). Follow the shape in [the feature map example](references/feature-map-example/README.md): a README index and one file per feature. Each file answers, from the user's point of view, what the feature is, how to reach it, how to drive it with the harness, and what observable end state proves it works. The four H2s are `Sub-features`, `How to get to it (user POV)`, `Driving it with <harness>` and `Gotchas`. If the seed data lacks a precondition a journey needs, the journey reports a failure and the reason goes in that feature's `Gotchas`; keep the journey as strict as the user path. The map is the maintained verification source: a proof that drives one convenient entry point is incomplete when the map lists others.

## 4. Prove the generated skill before handing it over

Run its own instructions end to end once: launch, doctor, drive one mapped feature, capture evidence, clean up. After cleanup, confirm the evidence still exists at the named location; a cleanup that eats the proof fails this step. Fix what fails, and run the generated cleanup after every failed iteration too, so broken attempts don't strand processes and ports. A generated skill that was never executed is a draft, not a deliverable. If you proved it in a stand-in for the real target (a container instead of a fresh VM, a local stack instead of a remote one), list every setup step the stand-in did that the target will not; those steps stay unverified until a run on the real target covers them.

## 5. Hand off

Report the skill path, the feature that was proven, and the evidence path. Point the user at the `maintain-verification-skill` skill for keeping the map honest as the app changes.

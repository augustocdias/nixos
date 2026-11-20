# pstack

Source: https://github.com/cursor/plugins/tree/main/pstack

Reviewed revision: `aaeb0ea` of `cursor/plugins`. MIT license (`pstack/LICENSE`, Lauren Tan): see LICENSE. The repository root carries no license file; the license covers the `pstack/` folder.

These are local adapted copies, not a flake input. Updates are deliberate copy-and-review operations verified in omp, Claude Code and Hermes.

## Copied and adapted skills

- `unslop`: local rule additions on top of upstream.
- `blast-radius`, `benchmark-checklist`, `sharpen`: upstream text with Cursor, playbook and `arena` references removed. `benchmark-checklist` adds the performance mantras from upstream's perf playbook.
- `catch-up`: upstream `ketchup`, renamed, without the video, `/bro` and `/visualize` parts.
- `typescript-best-practices`: upstream skill and `references/patterns.md`, with the two principle skills it cites inlined.
- `create-verification-skill`, `maintain-verification-skill`, `create-formal-verification-skill`, `maintain-formal-verification-skill`: generated skills go to the project's `.dev-skills/skills/`; Cursor control skills, PR steps and `/statechart` are removed. The formal skill's state chart replaces `/statechart` with TLC's own DOT dump, an `ALIAS` for reader-facing labels and an agent-written Mermaid conversion.

## Ideas folded into existing skills

- `code-review`: the Proof axis from upstream `interrogate`; the comment rule from upstream `no-comments` and its Comment Sicko agent (also in `WORKFLOW.md` and `implement`); the synced-flags smell and rerun-safety risk from the model-the-domain and idempotency principles.
- `retro`: upstream `reflect` and `correct`.
- `diagnosing-bugs`: the attack-the-premise and fix-root-causes principles.
- `tdd`: the test-behavior-not-implementation principle.
- `codebase-design`: rubric and reframe rules from upstream `arena`.
- `implement-spec`: the patch-id rule from upstream's shipping playbook.
- `research`: the Rationale mode from upstream `why`.
- `grilling`: settle empirical questions by prototype, from upstream `poteto-mode`.
- `handoff`: the authoritative-trail rule from upstream's session-pickup playbook.
- `writing-for-agents`: `EVAL.md` from upstream's eval playbook.

`rust-best-practices` is not from pstack: it is written from the Microsoft Pragmatic Rust Guidelines (MIT), the Rust API Guidelines and Clippy's lint documentation, credited in the skill.

# Curated Matt Pocock skills

Source: https://github.com/mattpocock/skills

Reviewed immutable revision: `5beb35b040e3de97e54fa9e386d7e42d15c295c2` (plugin version 1.3.1).

MIT license: see LICENSE. Preserve `pr/CREDITS.md` and all relevant workflow companions. These are local curated copies, not a flake input, runtime installer, or patch stack. Updates require deliberate copying, full workflow review, and verification of both harnesses.

## Original categories

Engineering: `code-review`, `codebase-design`, `diagnosing-bugs`, `domain-modeling`, `grill-with-docs`, `implement`, `implement-spec`, `improve-codebase-architecture`, `pr`, `prototype`, `research`, `retro`, `setup-matt-pocock-skills` (locally `setup-dev-skills`), `tdd`, `to-spec`, `to-tickets`, `triage`, `wayfinder`, `wizard`.

Productivity: `grill-me`, `grilling`, `handoff`, `teach`, `to-questionnaire`, `wait-what`, `writing-for-agents`.

`ask-matt`, experimental/misc/deprecated skills, upstream category indexes, and `agents/openai.yaml` are not installed.

## Local adaptations

- Shared packaging serves Claude Code and omp. Preserve upstream's fifteen manual and eleven contextual skill flags; use native Claude Skill or `/name`, and omp `read skill://name` or explicit `/skill:name`.
- Rename setup to `setup-dev-skills` everywhere. Keep `grill-with-docs` without an alias.
- A single authored WORKFLOW.md is copied into each installed skill root, together with attribution and license. Companion references remain within each skill root.
- Supporting artifacts use `.dev-skills/`, locally excluded through resolved Git `info/exclude`. Setup preserves user edits and existing authoritative documents, handles non-Git and separate-git-dir checkouts, and discovers actual tracker identifiers and schemas.
- No automated checkout, branch, or worktree lifecycle, including via delegates or host tools. `implement-spec` executes dependency-ordered tickets sequentially in the current checkout; failed validation blocks dependents. Humans choose branches and checkouts.
- Prototypes and research stay in local subfolders. Teaching, architecture reports, questionnaires, diagnostics, and wizards retain their full upstream processes, with workspace-relative output paths.
- User-reported errors are evidence. Existing delegation, approval, signed-commit, SOPS, Caveman chat-style, and Ponytail complete-but-minimal rules take precedence over generic heuristics.
- `code-review` and `pr` replace competing configured workflows without removing native harness review functionality. Tracker adapters research and propose mutations instead of imposing another ticket/spec schema.
- Generated wizard scripts run interactively by humans on the host. Architecture report CDN dependencies are disclosed; visual outputs require real rendering checks.
- Wizard GitHub secret/variable helpers pass `--repo "$GH_REPO"` explicitly, including when stages assign an unexported shell variable. A harmless regression fixture checks targeting from a different working directory and refuses writes without a configured repository.

Ignored artifacts require explicit sharing and backups. Remote publications must include accessible specification/evidence content rather than relying only on local workspace links.

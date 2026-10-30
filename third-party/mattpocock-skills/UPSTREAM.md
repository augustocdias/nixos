# Curated Matt Pocock skills

Source: https://github.com/mattpocock/skills

Reviewed immutable revision: `a496f5513d4a4cf889bc48e189e579f4b0bdf6aa`. Original curated baseline: `5beb35b040e3de97e54fa9e386d7e42d15c295c2`. The `v1.3.1` tag resolves to a different commit; it is not immutable provenance for either snapshot.

MIT license: see LICENSE. Preserve `pr-CREDITS.md` and all relevant workflow companions. These are local curated copies, not a flake input, runtime installer, or patch stack. Updates require deliberate copying, full workflow review, and verification of both harnesses.

## Original categories

Engineering: `code-review`, `codebase-design`, `diagnosing-bugs`, `domain-modeling`, `grill-with-docs`, `implement`, `implement-spec`, `improve-codebase-architecture`, `pr`, `prototype`, `research`, `retro`, `setup-matt-pocock-skills` (locally `setup-dev-skills`), `tdd`, `to-spec`, `to-tickets`, `triage`, `wayfinder`, `wizard`.

Productivity: `grill-me`, `grilling`, `handoff`, `teach`, `to-questionnaire`, `wait-what`, `writing-for-agents`.

`git-conventions` is a local skill, not from upstream; it shares this folder and its packaging only.

`ask-matt`, experimental/misc/deprecated skills, upstream category indexes, and `agents/openai.yaml` are not installed.

## Local adaptations

- Shared packaging serves Claude Code and omp: fourteen manual-only and twelve contextual skills. All contextual skills also support explicit manual commands. `implement` supports both manual invocation and contextual user-requested implementation or explicit orchestrator assignments; `implement-spec` remains manual-only. Use native Claude Skill or `/name`, and omp `read skill://name` or explicit `/skill:name`.
- Rename setup to `setup-dev-skills` everywhere. Keep `grill-with-docs` without an alias.
- A single authored WORKFLOW.md is copied into each installed skill root. Attribution and license live only in `third-party/`. Companion references remain within each skill root.
- Supporting artifacts use `.dev-skills/`, locally excluded through resolved Git `info/exclude`. Setup preserves user edits and existing authoritative documents, handles non-Git and separate-git-dir checkouts, and discovers actual tracker identifiers and schemas.
- `git-conventions` owns an upfront five-category Git/worktree agreement. The parent owns host approvals, credentials, signing, publication and shared progress. Distinct authorized worktrees permit concurrent fresh implementers; without worktrees, fresh implementers run sequentially. These are skill workflows, not command permission enforcement.
- `implement-spec` composes `implement` per ticket rather than upstream's direct `tdd` call. Small parent-relative stacked PRs replace the aggregate integration PR; any integration checkout is local-only. Implementation/commit/publication/tracker closure are distinct states. See `implement-spec/STACKS.md` for versioned GitHub mechanics.
- Prototypes may exercise real application routes and promote the chosen production design within scope. Prototype sources, variants and primary-source captures remain local, rather than on upstream's archive branch. Temporary route wiring is removed before production commits. Research, diagnostics, teaching, reports, questionnaires and wizards retain local artifact destinations without dropping their upstream workflows.
- Domain modeling updates the workspace glossary inline and applies upstream ADR criteria. Existing tracked glossaries/ADRs remain authoritative inputs; local disagreements are proposals, not canonical edits unless explicitly in task scope.
- Delegates receive the parent's absolute supporting workspace, including the narrow exception when it is outside their assigned checkout root. Supporting artifacts never enter implementation commits or pushes; tracked/staged artifacts block publication rather than being silently removed.
- User-reported errors are evidence. Existing delegation, approval, signed-commit, SOPS, chat-style and complete-but-minimal engineering rules take precedence over generic heuristics.
- `code-review` adds a quality checklist adapted from Ponytail's `ponytail-review` (MIT, DietrichGebert) and a one-line finding format adapted from Caveman's `caveman-review` (Apache-2.0, Julius Brussee). Provenance and licenses: `../README.md`.
- `code-review` and `pr` replace competing configured workflows without removing native harness review functionality. Tracker adapters research and propose mutations instead of imposing another ticket/spec schema.
- Generated wizard scripts run interactively by humans on the host. Architecture report CDN dependencies are disclosed; visual outputs require real rendering checks.
- Wizard GitHub secret/variable helpers pass `--repo "$GH_REPO"` explicitly, including when stages assign an unexported shell variable. A harmless regression fixture checks targeting from a different working directory and refuses writes without a configured repository.

Ignored artifacts require explicit sharing and backups. Remote publications must include accessible specification/evidence content rather than relying only on local workspace links.

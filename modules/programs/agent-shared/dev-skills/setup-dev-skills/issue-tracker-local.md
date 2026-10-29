# Issue tracker: Local Markdown

Issues and specifications live inside the absolute `.dev-skills/` workspace resolved for the turn. Paths below are workspace-relative, never subprocess-cwd-relative.

## Conventions

- One feature directory: `features/<feature-slug>/`.
- Specification: `features/<feature-slug>/spec.md`.
- One file per implementation ticket: `features/<feature-slug>/issues/NN-slug.md`, numbered from `01`; never combine all tickets in one file.
- Record `Status:`, `Parent:`, and `Blocked by:` near the top. Dependencies reference real ticket paths or unique numbers within the feature.
- Append comments under `## Comments`; do not erase earlier decisions.
- Read by the supplied path or resolve the feature and ticket number. List tickets by reading that feature's issue directory.
- Create and label by writing/updating the relevant file. Use the role strings in `triage-labels.md`; close with `Status: resolved` and actual completion evidence, not merely an attempted change.

## Publishing and fetching

Publishing creates or updates the owning local file. Specifications go to `spec.md`, not an issue body. Fetching reads the actual file and its comments, specification, and blockers. No remote mutation is needed.

## Wayfinding

The map is `features/<effort>/map.md`, containing Notes / Decisions-so-far / Fog. Child tickets live in its `issues/` directory.

- `Type:` is `research`, `prototype`, `grilling`, or `task`.
- `Status:` is `open`, `claimed`, or `resolved`.
- `Parent:` identifies the map. `Blocked by: NN, NN` names real child tickets.
- Frontier consists of open, unclaimed tickets whose blockers are all resolved. Select the first in map order, then ticket-number order.
- Claim by setting `Status: claimed` before work. One decision ticket per session.
- Resolve by appending the answer under `## Answer`, recording actual evidence, setting `Status: resolved`, and adding a gist plus relative link to the map's Decisions-so-far.
- Store research at `research/<slug>.md`, prototypes under `prototypes/<slug>/`, implementation progress at `features/<effort>/progress.md`, and genuine rejected enhancements at `out-of-scope/<concept>.md`.

Local ticket storage does not itself require Git mutations. When implementation or investigation needs branches, worktrees, commits, pushes, or PRs, follow the upfront `git-conventions` ownership agreement and parent-owned approval route. Supporting artifacts remain local and never enter implementation commits or publication. Failed required validation blocks dependent work. In `implement-spec`, readiness depends on verified prerequisite implementation and required commits, not ticket closure alone; record implementation, commit, publication, and closure separately in `progress.md`.

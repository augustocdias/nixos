---
name: setup-dev-skills
description: "Configure shared development skills: discover the project's tracker, triage vocabulary, domain documents, and standards; initialize a locally excluded .dev-skills workspace."
disable-model-invocation: true
---

# Setup development skills

Read [Shared workflow](WORKFLOW.md) first. This is a prompt-driven discovery and configuration conversation, not a runtime service or configuration parser. Explore, present evidence, resolve material choices, then write. Preserve existing user decisions on every rerun.

## 1. Explore the invocation directory

Retain its absolute path. This skill initializes exactly `<invocation-directory>/.dev-skills/`, even when invoked in a repository subdirectory. Detect whether the directory is in a non-bare Git working tree. Read relevant already supplied project instructions; discover authoritative glossary, ADR, and standards references without guessing or rewriting context files.

Inspect existing workspace files, Git remotes, available tracker connections, project metadata, and real labels/statuses. Monorepo signals include package workspaces and genuinely separate packages with their own source. Default to a single domain context unless evidence requires several.

Before any artifact writes:

1. Refuse a workspace/target symlink escape. Do not overwrite or migrate an unrelated directory.
2. In Git, check whether any target `.dev-skills/` files are tracked, including existing descendants. If so, stop: ignore rules cannot untrack them. Never run `git rm --cached` automatically.
3. Resolve the exclusion file with `git rev-parse --path-format=absolute --git-path info/exclude`. Do not assume `.git` is a directory. This also supports a separate-git-dir checkout and a human-provided linked checkout.
4. Append exactly one `.dev-skills/` line if absent, retaining existing content and newline boundaries. Use the unanchored directory pattern so initialization in a subdirectory is covered. Do not change `.gitignore`, global excludes, or Git configuration.
5. If the exclusion file is inaccessible, report its exact path and missing permission. Do not claim safe exclusion or silently continue writing unexcluded artifacts.

Outside Git, initialization may proceed, but explicitly report that Git exclusion is unavailable. A rerun after `git init` must complete exclusion.

## 2. Present findings and resolve configuration

Summarize what exists and what is missing. Lead each material choice with a recommendation. Use the harness's question UI, batching independent decisions when useful. Skip questions already settled by evidence or prior configuration. Do not ask users for identifiers tools can discover.

### A. Issue tracker

Use existing tracker configuration first. A GitHub remote suggests GitHub; a GitLab remote suggests GitLab. Local Markdown works without remote access or mutations. Linear uses the connected MCP and the custom-tracker path below. Ask only when tracker/project selection is genuinely ambiguous.

- GitHub: adapt [issue-tracker-github.md](issue-tracker-github.md) with the actual repository.
- GitLab: adapt [issue-tracker-gitlab.md](issue-tracker-gitlab.md) with the actual project.
- Local Markdown: use [issue-tracker-local.md](issue-tracker-local.md).
- Linear or another tracker: discover operation schemas and actual teams, projects, labels, statuses, and relationship support. Record concrete identifiers and verified operations for reading, creating, commenting, labeling/status changes, closing, parent links, blockers, and wayfinding claim/resolution. Return proposed remote mutations through the normal approval path. Do not include token values.

Keep upstream's PR/MR request-surface flag off by default. Do not raise an unnecessary choice; users can explicitly change it later.

### B. Triage vocabulary

Map `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix` to actual labels/statuses using [triage-labels.md](triage-labels.md). Prefer existing equivalents over duplicate labels. For local Markdown, these strings can be local statuses without creating anything remotely. Missing remote labels are proposals until approved and successfully created. Record that distinction honestly.

### C. Domain and standards

Default to workspace `GLOSSARY.md` and `adr/`. Offer `GLOSSARY-MAP.md` plus `domains/<context>/` only when actual bounded contexts justify it. Record existing authoritative documents as read-only references in `domain.md`; never move, overwrite, or untrack them. Use [domain.md](domain.md) for consumer rules. Discover genuine terminology and verified coding standards. Do not invent either.

## 3. Confirm material changes

Present discovered tracker/project selection, label mapping, domain layout, and any conflicts with prior choices. Resolve only unresolved material tradeoffs. Preserve existing user-edited documents and tracker decisions. Create missing documents; propose conflicting updates instead of replacing the directory. Do not add an Agent skills block to tracked context files.

## 4. Write shared prerequisites

Create these documents at the absolute workspace path, retaining existing content:

- `README.md`: purpose, selected project/tracker, document index, local sharing/backup and exclusion limitations, and invocation examples: Claude `/setup-dev-skills`, `/grill-me`; omp `/skill:setup-dev-skills`, `/skill:grill-me`, with contextual loading via `read skill://code-review`.
- `issue-tracker.md`: selected tracker, concrete identifiers, complete verified operations, parents/blockers, and wayfinding claims/resolutions.
- `triage-labels.md`: five-role mapping and any unapplied remote proposals.
- `domain.md`: domain layout, consumer rules, and links to authoritative existing documents.
- `GLOSSARY.md`: discovered/agreed terms, or an honest empty glossary header pending real domain work.
- `CODING_STANDARDS.md`: relevant verified rules and references, not new invented standards.

README indexes the lazy artifact locations from WORKFLOW.md. Do not create empty specs, ADRs, research reports, teaching missions, questionnaires, or tickets without task content.

## 5. Verify and report

In Git, run `git check-ignore` on all new supporting files and confirm exclusion came from the intended local rule. Check that tracked ignore/context files remain untouched. On rerun, preserve a user-added note, existing exclusion rules, and tracker decisions; avoid duplicate exclusion entries and create only missing prerequisites. Outside Git, report the exclusion limit rather than claiming files are ignored.

Report workspace's absolute path, tracker, existing authoritative sources, created/preserved documents, and unapplied remote proposals. Explain that users can edit the workspace documents; reruns fill gaps without resetting their choices. Other skills reuse the nearest initialized workspace within this checkout.

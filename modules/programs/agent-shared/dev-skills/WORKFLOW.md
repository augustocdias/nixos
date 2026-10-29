# Shared development-skills contract

Read this contract before the owning skill's workflow. Project instructions, the user's actual scope, safety requirements, and existing approvals take precedence over generic workflow heuristics.

## Invocation and style

Claude Code loads skills through its native Skill mechanism and `/name`. omp loads a skill with `read skill://name`; explicit invocation uses `/skill:name`. Use the installed companion paths within the skill root. Never traverse above that root through `skill://`.

Manual-only skills are `grill-me`, `grill-with-docs`, `setup-dev-skills`, `implement-spec`, `improve-codebase-architecture`, `retro`, `to-spec`, `to-tickets`, `triage`, `wayfinder`, `handoff`, `teach`, `to-questionnaire`, and `wait-what`. Their `disable-model-invocation: true` flag controls discovery and invocation, not permission. Suggest the user's manual command instead of automatically invoking them. Contextual skills also remain manually invocable. In particular, `implement` supports Claude `/implement`, omp `/skill:implement`, contextual user-requested implementation and explicit orchestrator assignments.

Caveman compresses chat, not meaning, files, comments, specifications, or lessons. Ponytail requires the smallest complete change, not shortened workflows or skipped verification. Keep its skipped-work/risk note outside any requested exact document format. Reuse agreed test seams and project conventions; do not manufacture abstractions, tests of implementation wording, or speculative scope.

## Workspace resolution

`setup-dev-skills` initializes `.dev-skills/` in its invocation directory. For every other skill, find the nearest existing initialized `.dev-skills/` walking from the invocation directory up to and including the current Git working-tree root. Never cross that root, enter a different checkout, or search unrelated home directories. Outside Git, check only the invocation directory. Resolve and retain an absolute workspace path for the turn. Pass that path explicitly to delegates and anchor all output there, regardless of subprocess cwd.

A delegated worker uses the parent's explicitly supplied absolute workspace even when it lies outside the assigned checkout's Git root. This narrow exception permits shared supporting artifacts, not unrelated filesystem traversal. Do not rediscover or initialize a second workspace. Use separate worker evidence files; only the parent writes shared progress.

An initialized workspace contains `README.md` and `issue-tracker.md`. If required configuration or output storage is absent, offer `/setup-dev-skills` (Claude) or `/skill:setup-dev-skills` (omp) before generating artifacts. Stateless review or explanation may proceed without setup. Native session stores, native plan-mode files, and installed read-only templates stay where their owners require them.

Do not follow a workspace or target symlink outside its intended directory. Preserve existing user documents and decisions. Existing tracked glossary, ADR, or standards documents may remain authoritative read-only inputs; record their locations in `domain.md`. Only a separately requested production-documentation change edits those sources.

Before artifact writes, reject symlink escapes and tracked workspace targets. Resolve the local exclusion with `git rev-parse --path-format=absolute --git-path info/exclude`; preserve existing rules and append one `.dev-skills/` directory pattern only if absent. An inaccessible exclude file blocks writes: explain its exact path and error. Never edit `.gitignore`, global excludes, or automatically untrack files. Outside Git, disclose that exclusion is unavailable.

## Artifact index

All paths below are relative to the retained absolute workspace, not the repository root:

| Content | Path |
| --- | --- |
| Setup/configuration | `README.md`, `issue-tracker.md`, `triage-labels.md`, `domain.md`, `CODING_STANDARDS.md` |
| Domain | `GLOSSARY.md`, optional `GLOSSARY-MAP.md`, `adr/NNNN-slug.md` |
| Bounded contexts, only when needed | `domains/<context>/GLOSSARY.md`, `domains/<context>/adr/` |
| Local specification | `features/<slug>/spec.md` |
| Local tickets and dependencies | `features/<slug>/issues/NN-slug.md` |
| Map and implementation progress | `features/<slug>/map.md`, `features/<slug>/progress.md` |
| Research | `research/<slug>.md` |
| Prototypes | `prototypes/<slug>/`, including `result.md` |
| Architecture reports | `reports/architecture-<timestamp>.html` |
| Rejected enhancements | `out-of-scope/<concept>.md` |
| Handoffs / questionnaires | `handoffs/<slug>.md`, `questionnaires/<slug>.md` |
| Diagnostics and evidence | `debug/<slug>/` |
| Teaching mission, resources, notes, learning glossary, lessons, references, learning records, assets | `teach/<topic>/` |
| Human-run wizard and state | `wizards/<slug>.sh` and supporting files beside it |
| Saved reviews / retrospectives, only when requested | `reviews/<slug>.md`, `retros/<slug>.md` |

Remote specifications, tickets, and comments stay in the configured tracker. Include full necessary content or approved accessible attachments when publishing. An inaccessible local `.dev-skills/` link is not a published specification. Never include secrets or sensitive payloads in local artifacts or remote reports. Local ignore rules provide neither encryption nor backup exclusion and do not prevent `git add -f`.

## Checkout, delegation, and approvals

Load `git-conventions` when the workflow needs Git mutations. Agree branch, worktree, commit, push and PR ownership before mutations; read-only work needs no agreement. Authorized distinct worktrees permit concurrent implementations; otherwise use one coding worker at a time in the current checkout. Failed required verification blocks dependents, not independent work. Preserve unrelated changes without automatic stash/reset. `implement-spec` always uses fresh implementers, even for one ready ticket.

Existing permissions remain unchanged. Remote mutations, label creation, publication, pushes, and signed commits use normal approval routes. Headless adapters return exact proposed tool calls for the parent to approve; they do not bypass permissions. A declined commit is not a completed commit. Native `/review` and native helpers remain available; `code-review` is the canonical configured diff-review workflow. `pr` owns PR-body structure, subject to a real repository template and `git-conventions` title/issue/safety rules.

The parent owns approval-dependent actions and credentials. When Git-over-SSH is needed, obtain `host_ssh_agent` approval before any worker starts; pass the approved socket path to applicable workers. Rejection does not permit another credential route. Workers return evidence, intended production paths and pending actions; the parent stages explicit production paths and handles signed commits/pushes through the required host route. Preserve Darwin's existing signing route outside the Linux jail.

Before commits or publication, inspect tracked and staged supporting artifacts. If any `.dev-skills/` artifacts are tracked or staged, stop publication and explain the conflict without discarding or untracking user work. Never force-add supporting artifacts, temporary preview wiring, or artifact archive branches. Authorized PR bodies and tracker summaries may contain concise necessary evidence, not uploaded supporting files or inaccessible local links. Sharing generated artifacts needs a separate explicit request.

Wizard scripts are for humans to run on the host. Give the exact host command. Do not run credential, provisioning, deployment, or privileged stages from the agent. Anchor scratch state beside the wizard, not its caller's cwd; explicitly distinguish an intended external target from supporting state. Use SOPS for this repository's secrets and never print their values.

Accept user-reported failures as evidence; do not rerun merely to confirm the report. Seek reproducible causal evidence through safe, one-variable probes. Verify actual changed behavior, rendered reports/previews, and generated scripts. Never invent before/after evidence, recipient facts, deadlines, terminology, or remote label existence.

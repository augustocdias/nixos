---
name: git-conventions
description: Augusto's git commit, branch, and PR conventions. Use when writing commit messages, drafting PRs, or creating branches, to match a consistent style across repos.
---

# Git conventions

Personal defaults. A project's own AGENTS.md / CONTRIBUTING.md overrides these.

## Commits

- **Conventional Commits**: `type(scope): subject`.
  Types: `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `chore`, `build`,
  `ci`, `style`, `revert`.
- Subject: imperative mood, lowercase after the colon, no trailing period,
  aim for ≤ 50 chars.
- Body (optional, only when the change isn't self-explanatory): explain **why**,
  not what. Wrap at ~72 chars. Separate from subject with a blank line.
- One logical change per commit. Don't bundle unrelated changes.
- Never commit secrets, generated artifacts, or debug leftovers.
- Match the repo's existing style first — inspect `git log --oneline -15`
  before writing.

## Branches

- `type/short-description` (e.g. `feat/opencode-agents`, `fix/lock-race`).
- Reference a ticket id when one exists (e.g. `feat/ABC-123-add-agents`).

## Pull requests

- Title mirrors the primary commit/change set.
- Body: **Summary** (what + why) → **Changes** (bullet list) → **Testing**
  (how it was verified). Follow a repo `.github/pull_request_template.md` if
  present.
- Link related issues/tickets.
- Keep PRs focused and reviewable; split large ones.

## Safety

- Never `push --force` to shared branches; use `--force-with-lease` only on your
  own feature branch and only when needed.
- Rebase local WIP, but don't rewrite already-shared history.

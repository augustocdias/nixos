---
name: git
description: "Use before any Git mutation (branch, worktree, commit, push or PR) and when writing commit messages, branch names or PR titles."
version: 1.0.0
metadata:
  hermes:
    tags: [git]
    category: devops
---

# Git

Hermes agents own branches, worktrees, commits, pushes and PRs; nothing waits on a human agreement. A project's own AGENTS.md or CONTRIBUTING.md overrides these defaults.

## Signing

The terminal's Git config signs every commit and tag with the agent SSH key and pushes over SSH with that key. Keep it: add no other key, signing program or credential helper. Before every push, `git log --format='%H %G?' <remote-head>..<head>` prints `G` for each outgoing commit.

## Commits

- **Conventional Commits**: `type(scope): subject`. Types: `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `chore`, `build`, `ci`, `style`, `revert`.
- Subject: imperative mood, lowercase after the colon, no trailing period, aim for 50 chars, hard cap 72.
- Body only when the change isn't self-explanatory: the **why**, wrapped at about 72 chars, `-` bullets, issue references (`Closes #42`, `Refs #17`) last.
- A body is required for breaking changes (`type(scope)!:` plus a `BREAKING CHANGE:` footer), security fixes, data migrations and reverts.
- The diff says what changed: write the subject and body without "this commit", "I", "we", "now" or "currently". Emoji only when the repo uses them.
- Write the body by the `unslop` skill.
- Commits carry no `Co-Authored-By` or other agent attribution trailer.
- One logical change per commit. Secrets, generated artifacts and debug leftovers stay out.
- Match the repo's style first: read `git log --oneline -15` before writing.

## Branches

- `type/short-description`, such as `fix/lock-race`.
- Include the ticket id when one exists: `feat/ABC-123-add-agents`.
- A branch named in the card's Git row wins.

## Worktrees

- The coordinator creates one worktree per branch, beside the repo's other checkouts: `git -C ~/dev/<repo>/<main checkout> worktree add ~/dev/<repo>/<branch-slug> -b <branch>`. The card's Repo row names it. A repo with a single active card stays in its main checkout.
- The reviewer removes the worktree once the card's work is published and approved, before `kanban_complete`. Run Git from the main checkout, never from inside the worktree: `git -C <main checkout> worktree remove <path>`. The branch stays; a later fix-up recreates the worktree with `git worktree add <path> <branch>`.
- Remove only a path that `git worktree list` shows as a linked worktree, never the main checkout, and only when no other open card's Repo row names it (`kanban_list`). Never pass `--force`.
- A failed or skipped removal never blocks completion. Post this comment, then complete the card:

  ```markdown
  ## ⚠️ Cleanup needed: `<path>`

  <the shortest decisive error line, or "another open card uses it">
  ```

## Pull requests

- The title mirrors the primary commit.
- Use the `pr` skill for the body. A repository PR template wins over its default shape.
- Link related issues and tickets.
- Keep PRs focused; split large ones.

## Safety

- Merging, force-pushing a shared branch and deleting unrelated work need the user.
- A non-fast-forward rejection stops the push; report it instead of forcing.
- Preserve unrelated user work. Verify actual refs, commits and remote effects; a partial effect is not a rollback.
- Use an explicit remote and refspec, and an explicit PR repository, head and base.

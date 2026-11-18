# Global instructions

## Evidence and decisions

- Fetch current documentation with context7 before explaining library or API behavior. Link official documentation or authoritative sources for technical claims.
- Distinguish verified facts from inference. If no source is available, say the claim rests on general knowledge and needs verification.
- Get dates from a tool when the task needs the current date; never guess.
- Resolve repository facts with tools. Ask the user about materially different scope or behavior choices, not information available in the repository.

## Commands

Commands already start in the workspace. Never `cd` into the current directory; use the tool's cwd or directory option for another directory.

## Git

Before any Git mutation, load `git-conventions` and agree ownership; read-only work needs none.

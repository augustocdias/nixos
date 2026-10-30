# Global instructions

## Evidence and decisions

- Fetch current documentation with context7 before explaining library or API behavior. Link official documentation or authoritative sources for technical claims.
- Distinguish verified facts from inference. If no source is available, say the claim rests on general knowledge and needs verification.
- Get dates from a tool when the task needs the current date; never guess.
- Resolve repository facts with tools. Ask the user about materially different scope or behavior choices, not information available in the repository.

## Commands

Commands already start in the workspace. Use relative paths and the tool's cwd/directory option for another directory; never re-enter the current directory with `cd`.

## Instruction ownership

The chat-style section owns how replies read; the engineering section owns minimal-but-complete changes. Both appear below and stay active until the user turns them off. Follow their safety, exact-output, and persisted-document exceptions. Neither changes approvals or sandbox boundaries. Linux sandbox operations are governed by the separately loaded sandbox contract.

## Development skills

Use `code-review` for configured diff review, `pr` for PR bodies, and explicitly invoked `to-spec` / `to-tickets` for specification and ticket workflows. Native harness review remains available.

Read each skill's packaged `WORKFLOW.md` for the workspace contract. Shared setup and new supporting artifacts live in locally excluded `.dev-skills/`; keep existing authoritative tracked documents intact. Local exclusion is neither encryption nor backup; sharing requires an explicit action.

Git mutations follow the upfront five-category ownership agreement in `git-conventions`; read-only work needs none. Delegates inherit that run's scope, while the parent owns approval-dependent actions. A delegated checkout may use only its parent's explicitly supplied absolute `.dev-skills/` workspace outside its Git root. Existing approvals, signed-commit routes, and project rules retain precedence.

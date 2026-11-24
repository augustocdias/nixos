# Role

Implement tickets, fix bugs and address review findings directly in this Hermes session.

Create signed commits and keep them local for independent review. The reviewer pushes and creates or updates the PR after approval. This also applies to fix-ups on an existing PR.

Request review in the same run after implementation and required local checks pass. Review feedback returns to this role; fix forward on the same branch and preserve PR identity.

# Required skills

| Trigger                                                   | Skill                                                                                                          |
| --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Every card, right after `kanban_show`                     | `implement`, as direct invocation; it requires `tdd` before code and `code-review`(in a sub-agent with fresh context) before handoff |
| Before the first branch, commit or commit message         | `git`                                                                                                          |
| A failure whose cause you do not know                     | `diagnosing-bugs`                                                                                              |
| An explicitly requested throwaway experiment              | `prototype`                                                                                                    |
| Writing commit bodies, code comments, docs or the handoff | `unslop`                                                                                                       |
| Editing `AGENTS.md`, skills or other agent-facing docs    | `writing-for-agents`                                                                                           |

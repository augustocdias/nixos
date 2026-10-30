# Skill mechanics

The skill-specific branch of [`writing-for-agents`](SKILL.md): what changes when the document is a skill (frontmatter, the invocation choice, and router skills). Everything else about writing it is the universal reference in `SKILL.md`.

## Invocation

Claude Code loads skills through its native Skill mechanism; users invoke `/name`. omp loads a skill with `read skill://name`; users invoke `/skill:name`. Use these harness-native forms rather than assuming a Claude-only tool. Companion links resolve within the installed skill root; do not use `../` to reach a shared contract outside that root.

Two choices, trading the two loads:

- A **model-invoked** skill keeps a `description`, so the agent can fire it autonomously, and other skills can reach it. You can still type its name: model-invocation always _includes_ user reach; a description only ever adds agent discovery, never removes the human's. The description is the skill's top-level context pointer in model discovery: context load in exchange for discoverability. The harness controls when and how that metadata is presented; do not assume that every description remains in context on every turn. A model-invoked skill whose content is all reference is also one home for shared reference: another skill can invoke it, so reference needed by several skills lives in one place. Mechanics: omit `disable-model-invocation`, and write a model-facing description carrying the trigger branches (the pointer-writing rules in `SKILL.md` apply in full).
- A **user-invoked** skill is manual-only: the user chooses when to invoke it. Set `disable-model-invocation: true`; keep a human-facing one-line `description` with trigger lists stripped. Claude Code honors the manual-invocation flag; omp maps it to hidden model discovery while retaining explicit `/skill:name` access. Manual skills spend cognitive load: the human is the index that remembers them. A direct filesystem or `skill://` read may still be technically possible; that is not permission to launch the manual workflow automatically. Suggest the manual command and wait for the user's choice.

Pick model-invocation only when the agent must reach the skill on its own, or another skill must. If it only ever fires by hand, make it user-invoked and pay no context load.

Shared reference that two user-invoked skills both need should not require launching either manual workflow. Keep it in a plain companion file that both can read. For these packaged skills, the build copies the single authored `WORKFLOW.md` into each installed skill root; link `[Shared workflow](WORKFLOW.md)` before the workflow. Do not introduce a shared-contract skill or rely on parent-directory traversal. Discovery and invocation flags do not grant authorization; existing approval rules still apply.

## Splitting by invocation

The invocation cut of splitting (the sequence cut lives in `SKILL.md`): split off a model-invoked skill when you have a distinct leading word that should trigger it on its own (a trigger word you actually use in your prompts), or another skill must reach it. You pay context load for the new always-loaded description, so that independent reach has to be worth it.

## Router skills

When user-invoked skills multiply past what you can remember, that piled-up cognitive load is cured by a **router skill**: one user-invoked skill that names the others and when to reach for each, so the human has one skill to remember instead of many. For manual targets it suggests the next command rather than launching them automatically. A router may load a contextual target through the native mechanism; for example, manual `grill-me` routes to contextual `grilling`.

# Hermes researcher provenance

- Source: https://github.com/AlekseiUL/hermes-researcher-agent
- Reviewed revision: `e06679c2bb488290399b222637541539a8fc2547`.
- Copyright: 2026 Aleksei Ulianov / Sprut_AI.
- License: MIT, reproduced in `LICENSE`.

## Adapted sources

- `skills/research-intelligence/SKILL.md` supplies the evidence method in `modules/programs/agent-shared/skills/research/SKILL.md`.
- `skills/research-intelligence/references/research-modes.md` supplies the conditional checks in that skill's `references/research-modes.md`.
- `skills/research-intelligence/templates/research-brief.md` supplies the structure of that skill's `templates/research-brief.md`.

The existing research skill retains its Matt Pocock-derived workspace and delegation workflow. These additions are curated text, not a flake input or an installed upstream Hermes profile.

## Local adaptations

- Keep the `research` name and shared packaging for omp, Claude Code and Hermes.
- Preserve the shared workspace, delegation, approval and publication contract.
- Keep quick lookups inline in the main procedure and disclose specialized checks only when needed.
- Allow authorized internal and local evidence while keeping private context out of public queries and third-party extractors.
- Use existing harness tools and browser routing instead of upstream-specific helper commands.
- Keep the source ledger in one Markdown findings file. Do not require the upstream JSON schema or validator.
- Accept a single authoritative specification or implementation for facts it defines. Seek independent corroboration for consequential or disputed conclusions and label gaps.
- Omit the upstream profile, collector scripts, document conversion dependencies, YouTube pack and scheduled jobs.

Review upstream changes deliberately before copying them. Preserve the license and update this revision and adaptation record together with the affected skill text.

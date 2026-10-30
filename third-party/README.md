# Third-party credits

Licenses and provenance for text copied or adapted into this repository. Nothing here is installed or loaded by any harness.

## Credits

- **Matt Pocock**: [mattpocock/skills](https://github.com/mattpocock/skills). The curated skills in `modules/programs/agent-shared/skills/` (all except `git-conventions`). MIT, see `mattpocock-skills/LICENSE`; provenance and local adaptations are in `mattpocock-skills/UPSTREAM.md`.
- **Dex Horthy**: the `show-me` skill from [humanlayer](https://github.com/humanlayer/humanlayer). The visual menu in the `pr` skill, see `mattpocock-skills/pr-CREDITS.md`.
- **Julius Brussee**: [Caveman](https://github.com/JuliusBrussee/caveman). The chat-style rules (`agent-shared/style/caveman.md`), the one-line finding format in `skills/code-review`, and the commit rules in `skills/git-conventions`. Apache-2.0, see `caveman/`.
- **Dietrich Gebert**: [Ponytail](https://github.com/DietrichGebert/ponytail). The engineering rules (`agent-shared/style/ponytail.md`) and the quality checklist in `skills/code-review`. MIT, see `ponytail/LICENSE`.

## Caveman

- Source revision: `9b68f7ed12b05e7efaff18e65c5a3fc2849fd0a4` (4.0.1).
- Copyright 2026 Julius Brussee.
- License: Apache License 2.0 (`caveman/LICENSE`). `caveman/NOTICE` and the pre-3.0.0 MIT notice (`caveman/LICENSE-MIT`) are carried verbatim.
- Copied from: `skills/caveman/SKILL.md`, into `agent-shared/style/caveman.md`.
- Modifications (Apache-2.0 §4b):
  - Condensed the rules to the default intensity.
  - Removed the frontmatter, the `/caveman` level switching, the ultra/wenyan aliases, status reporting and hook-based activation. The rules load as always-on context instead.
  - Folded the caveman-review one-line finding format into `skills/code-review`.
  - Folded the caveman-commit rules into `skills/git-conventions`.

## Ponytail

- Source revision: `96608e078b2d5ea607c5c3b8b5a54d1c1fba6846` (5.3.3).
- Copyright (c) 2026 DietrichGebert.
- License: MIT (`ponytail/LICENSE`).
- Copied from: `skills/ponytail/SKILL.md`, filtered to the `full` level (as `hooks/ponytail-instructions.js` does), into `agent-shared/style/ponytail.md`.
- Modifications:
  - Removed the frontmatter, the levels table and level switching.
  - Folded the `ponytail-review` checklist into `skills/code-review`.

Hermes still uses the upstream Caveman and Ponytail integrations through their flake inputs. Updating any copy here is a deliberate copy-and-review operation.

# NixOS + nix-darwin configuration

Declarative Den/aspect configuration for `augusto` across three hosts:

| Host | Platform | Role |
| --- | --- | --- |
| `laptop` (`nixos`) | x86_64-linux | NixOS, Hyprland, DankMaterialShell, Home Manager |
| `macmini` | aarch64-darwin | nix-darwin, Home Manager, OmniWM, voice services |
| `raspi` (`home`) | aarch64-linux | Headless Home Assistant appliance; no Home Manager user |

## Before editing or diagnosing

**Read every matching topic below before editing or diagnosing its subsystem.** Source files remain authoritative for current values. Update the owning topic in the same change when documented behavior changes; do not re-expand this root into a handbook.

| Trigger | Required reference |
| --- | --- |
| Host/aspect/input/layout changes; deployment; boot, networking, power, security; common administration | [System](docs/system.md) |
| HA integrations/components/resources; broker consumers; hand-pinned sources; HA deployment diagnosis | [Home Assistant](docs/home-assistant.md) |
| Voice routing, models, translation, Laya evaluation, Open WebUI/tools | [Voice services](docs/voice-services.md) |
| Compositor, greeter, window manager, keyboard, session, desktop shell | [Desktop](docs/desktop.md) |
| Panes, workspaces, worktrees, helpers/plugins, sidebar telemetry, agent lifecycle integration | [Herdr](docs/herdr.md) |
| Editor, plugin, build, LSP, formatter, linter | [Neovim](docs/neovim.md) |
| Harness prompts/settings/extensions/skills/models/MCPs/approvals/sandbox | [Coding agents](docs/coding-agents.md) |

## Module conventions

- Den composes `den.aspects.<name>` using `nixos`, `darwin`, `homeManager`, and `includes`. An aspect only applies when included.
- `import-tree ./modules` discovers `.nix` modules recursively. `_`-prefixed helpers are excluded and imported manually.
- Declare inputs in the owning module with `flake-file.inputs`, not directly in generated `flake.nix`. Regenerate with `nix run .#write-flake`.
- Cross-platform user aspects belong in `modules/user/base.nix` and must build on Linux and Darwin. Linux-only aspects belong in `modules/user/linux.nix`; Darwin-only aspects belong in `modules/user/mac.nix`. Host/hardware wiring lives in `modules/hosts.nix` and host aspects.
- Multi-file programs use `modules/programs/<name>/<name>.nix`, with a matching aspect name. Single-file programs use `modules/programs/<name>.nix`.
- Format Nix with Alejandra and Lua with StyLua (spaces, single quotes). Match Catppuccin Mocha where applicable.
- Use current `nixos` MCP information before changing package attributes, options/types, flake-input assumptions, or store-path conclusions. Inspect source rather than guessing.

## Safety and verification

- Never commit plaintext secrets. Use sops-nix; encrypted API keys live in `modules/security/secrets/env.yaml`. Read the `sops-secrets` skill before adding or exposing secrets.
- Shared jail and permission changes affect both omp and Claude Code. Read [Coding agents](docs/coding-agents.md) first; keep approvals and sandbox boundaries intact.
- Exercise changed behavior with the relevant focused checks. After changing `agent-shared/_bash.nix` or a harness `_permissions.nix`, inspect rendered rules, not only source.
- Preserve human ownership of branches/checkouts and existing workflow/approval routes. [Coding agents](docs/coding-agents.md#development-skills) owns development-skill routing and local workspace boundaries.
- Record exercised checks and limits accurately. Keep troubleshooting recipes and verification commands in their owning topic.

# NixOS + nix-darwin configuration

Declarative Den/aspect configuration for `augusto` across three hosts:

| Host | Platform | Role |
| --- | --- | --- |
| `laptop` (`nixos`) | x86_64-linux | NixOS, Hyprland, DankMaterialShell, Home Manager |
| `macmini` | aarch64-darwin | nix-darwin, Home Manager, OmniWM, voice services |
| `raspi` (`home`) | aarch64-linux | Headless Home Assistant appliance; no Home Manager user |

## Topic docs

**Read every matching topic before editing or diagnosing its subsystem.**

| Trigger | Topic |
| --- | --- |
| Hosts, aspects, inputs, layout; deployment; boot, networking, power, security | [System](docs/system.md) |
| Home Assistant integrations, components, resources; broker consumers; hand-pinned sources | [Home Assistant](docs/home-assistant.md) |
| Voice routing, models, translation, Laya, Open WebUI | [Voice services](docs/voice-services.md) |
| Compositor, greeter, window manager, keyboard, session, desktop shell | [Desktop](docs/desktop.md) |
| Herdr panes, workspaces, worktrees, plugins, sidebar, agent lifecycle | [Herdr](docs/herdr.md) |
| Neovim plugins, LSP, formatters, linters | [Neovim](docs/neovim.md) |
| Harness prompts, settings, skills, models, MCPs, approvals, sandbox, jail; work Hermes delegator | [Coding agents](docs/coding-agents.md) |

Topic docs are a snapshot of the current system. Source files win when they disagree. When a change alters documented behavior, load the `writing-for-agents` skill and edit the owning topic in the same change:

- Describe the system as it is now. When you remove something, delete its lines; leave no note that it existed.
- Record what the source cannot show: gotchas, cross-module wiring, the reason behind a surprising choice, verification commands and troubleshooting recipes.
- Leave values, lists and versions that one file or command reveals in the source, and name the owning file instead.
- Keep this file to routing and repo-wide rules.

## Module conventions

- Den composes `den.aspects.<name>` using `nixos`, `darwin`, `homeManager`, and `includes`. An aspect only applies when included.
- `import-tree ./modules` discovers `.nix` modules recursively. `_`-prefixed helpers are excluded and imported manually.
- Declare inputs in the owning module with `flake-file.inputs`; `flake.nix` is generated. Regenerate with `nix run .#write-flake`.
- Cross-platform user aspects belong in `modules/user/base.nix` and must build on Linux and Darwin. Linux-only aspects belong in `modules/user/linux.nix`; Darwin-only aspects belong in `modules/user/mac.nix`. Host/hardware wiring lives in `modules/hosts.nix` and host aspects.
- Multi-file programs use `modules/programs/<name>/<name>.nix`, with a matching aspect name. Single-file programs use `modules/programs/<name>.nix`.
- Format Nix with Alejandra and Lua with StyLua (spaces, single quotes). Match Catppuccin Mocha where applicable.
- Check package attributes, options and types, flake inputs and store paths with the `nixos` MCP before changing them.

## Safety and verification

- Keep secrets encrypted with sops-nix; API keys live in `modules/security/secrets/env.yaml`. Read the `sops-secrets` skill before adding or exposing a secret.
- Jail and permission changes affect both omp and Claude Code; keep approvals and sandbox boundaries intact. After changing `agent-shared/_bash.nix` or a harness `_permissions.nix`, inspect the rendered rules, not only the source.
- Preserve human ownership of branches and checkouts and existing approval routes. Development-skill routing and `.dev-skills/` workspace boundaries follow [Coding agents](docs/coding-agents.md#development-skills).
- Exercise changed behavior with the focused checks its topic names, and report which checks ran and what they did not cover.

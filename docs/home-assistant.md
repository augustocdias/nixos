# Home Assistant reference

Host, MQTT, and deployment details live in [System](system.md#raspberry-pi-host--raspi); voice behavior lives in [Voice services](voice-services.md). The aspect is `modules/services/home-assistant/home-assistant.nix`.

## Home Assistant

HA runs as native `services.home-assistant` on `raspi`. There is no Supervisor, no add-ons, and no HACS: custom components, cards, and themes are all Nix-declared.

### Integrations (`_components.nix`)

`extraComponents` must name every integration in use, including ones that arrive transitively. The NixOS module derives the unit's systemd hardening from this list, not only Python dependencies. Dropping `zha` removes serial device access; dropping `bthome` or `default_config` removes Bluetooth sockets and capabilities.

Config entries live in `.storage`, which Nix cannot see. Adding an integration takes two steps: add it to `_components.nix` and rebuild, then add it in the HA UI.

- `homekit_controller` and `switchbot` are listed but unconfigured. Discovery starts their config flows, and a flow for a missing integration cannot load, cannot be dismissed, and retries forever.
- `ibeacon` stays out on purpose. It would create a device for every passing beacon; its missing-integration log line on each start is accepted.
- `go2rtc` stays out on purpose. It is a system dependency of `default_config`, recreates its own config entry, and self-disables when no URL is configured. Deleting its entry in the UI has no effect.
- `extraPackages` supplies optional aiohttp compression backends; without them HA logs degraded websocket compression.

### Configuration

`configuration.yaml` is Nix-owned (`config` in the aspect). The `!include` targets (`groups`, `automations`, `scripts`, `scenes`, `templates`) stay mutable under `/var/lib/hass` so the UI editors keep working. The module unquotes leading `!` when rendering, which is what makes `!include` work from a Nix string.

Leave `frontend.themes` and `lovelace.resources`/`resource_mode` out of `config`. Setting `themes` and `customLovelaceModules` already makes the module own both.

To check what reached HA's Python environment, inspect `systemd.services.home-assistant.environment.PYTHONPATH`. `services.home-assistant.package` is the un-overridden package and looks empty.

### ha-mcp (`_ha-mcp.nix`)

ha-mcp exposes HA as an administration API over MCP: automations, scripts, scenes, helpers, dashboards, registries, history, and templates. Core's `mcp_server` integration is a different thing (Assist intents only) and is not used.

It has two halves with different owners:

- `ha_mcp_tools`, the custom component from `homeassistant-ai/ha-mcp-integration`, is packaged in `_ha-mcp.nix`. Its `dependencies` are checked against `manifest.json` at build time. The `mcp` dependency is the shared copy the component imports; the server vendors its own, so keep both.
- The server is nixpkgs' `python3Packages.ha-mcp`. The component's config entry runs it in process inside HA's interpreter, reached through `dependencies`, `propagatedBuildInputs`, and the module's `extraPackages`. The server version is whatever nixpkgs ships.

HA always sets `skip_pip`, so the component never pip-installs or auto-updates the server. Its update entity has no Install button, and the channel, auto-update, and pip-spec options in the integration UI are inert.

Version coupling: the component raises `component_outdated` or `server_update_held` repairs when it is the older half. The reverse case has no warning: a component newer than the nixpkgs server fails at server start with an `ImportError` from `embedded_server.py`. On every component bump, check its `from ha_mcp ...` imports against the server nixpkgs currently ships. The component also enforces a minimum HA version (`MIN_EMBEDDED_HOME_ASSISTANT_VERSION`).

Networking: the primary route is an HA webhook on port 8123, so `webhook` is in `_components.nix`. The server also binds a direct listener on port 9584 behind a random secret path. Port 9584 stays closed in `raspi.nix`, so the direct URL on the entry's Configure screen is unreachable from the LAN. Use the webhook URL with `ha_auth`; open 9584 only if the direct listener is wanted.

### Keeping the pins current (`pins.nix`)

Two signals self-report: the ha-mcp server update entity (which shows when nixpkgs is behind upstream) and the `component_outdated` repair. Nothing else watches the hand-pinned sources.

`pins.nix` re-exports the HA pins as `packages.hass-*` only for `nix-update`, on Linux systems only. The aspect still `callPackage`s the same files. `update-system` stage [2/4] updates them, builds each one, and skips them with `--skip-pins`. The optional `passthru` knobs (`updatePolicy`, `updateFile`, `updateVersionRegex`) are documented in `modules/scripts/update-system/update-system.fish`. Bump one pin by hand with `nix-update -f . -F <pkg>` from the dev shell.

Rules for writing pins:

- Components built with `buildHomeAssistantComponent` need `updateFile`. `extendMkDerivation` points their position info into nixpkgs, and nix-update then refuses with `... is not in /nix/store/...-source`.
- Upstreams that tag prereleases beside stable releases need `updateVersionRegex`. The regex matches the raw tag before `v` is stripped, so write it as `^v?(...)$`.
- Keep every version and tag string unique within its file. nix-update anchors on `unsafeGetAttrPos "src"`, which reports the wrong line for `mkCard`, `mkTheme`, and `extendMkDerivation` pins. It then falls back to a whole-file string replace, after an unconditional whole-file rev replace. Prefer one pin per file for anything new.
- Version `"branch"` pins as `<base>-unstable-<date>` with the full rev in `rev`. A short rev inside the version string gets rewritten by the rev replace and breaks the version substitution.

Firefox and Thunderbird extensions use their own `update-firefox` and `update-thunderbird` scripts. nix-update cannot replace them: Firefox fetches extensions at runtime from policy `install_url`s, and Thunderbird's versions come from the AMO API.

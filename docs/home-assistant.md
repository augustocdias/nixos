# Home Assistant reference

Read before changing HA integrations, components, resources, broker consumers, or hand-pinned sources, and before diagnosing HA deployment. Host, MQTT, and deployment details live in [System](system.md#raspberry-pi-host--raspi); voice behavior lives in [Voice services](voice-services.md). Source files remain authoritative for current values.

Version-coupling and verification observations below retain their original test conditions. References to earlier checks, including “today,” are historical notes, not verification of the current checkout; recheck the relevant imports and pins when updating them.

## Home Assistant

Runs as native `services.home-assistant` on `raspi`. **There is no Supervisor and there are no add-ons** — HAOS/Supervised cannot be expressed declaratively. Everything HACS used to manage is now Nix-declared.

`extraComponents` in `_components.nix` **must name every integration in use**. It is not just about python dependencies: the NixOS module derives the unit's systemd hardening from it. Drop `zha` and the service loses `SupplementaryGroups=dialout` + `DeviceAllow=char-ttyUSB` (133 entities die); drop `bthome`/`default_config` and it loses `AF_BLUETOOTH` + `CAP_NET_ADMIN`/`CAP_NET_RAW`, killing the BLE thermometers. HA's config entries live in `.storage`, which Nix cannot see, so nothing infers them — **adding an integration is two steps: add it to `_components.nix` and rebuild, _then_ add it in the HA UI.**

`homekit_controller` and `switchbot` are listed but unconfigured: zeroconf/BLE discovery starts their config flows, and without the integration present the flow cannot load, so it cannot be dismissed either and retries forever. `ibeacon` is deliberately absent and still logs that error on each start — it auto-creates a device for every passing beacon, which is not worth a clean log.

`extraPackages = ps: [zlib-ng isal]` supplies the optional aiohttp compression backends; without them HA logs that websocket compression is degraded.

- **`configuration.yaml` is Nix-owned** (`configWritable = false`) and mirrors the previous file: `default_config`, `bluetooth`, `tts` and `!include` lines for `groups/automations/scripts/scenes/templates.yaml`. Those five stay **mutable** under `/var/lib/hass` so the HA UI editors keep working. (Note `template: !include templates.yaml` — not the older `sensor: !include sensors.yaml`, which nested a `template:` block under `sensor:`.) The module unquotes leading bangs when rendering YAML (`sed` on the generated file), which is what makes `!include` work from a Nix string.
- **Do not set `frontend.themes` or `lovelace.resources`/`resource_mode` in `config`** — setting `themes` and `customLovelaceModules` makes the module take authoritative control of both.
- **`go2rtc` is deliberately not in `_components.nix`, and that is correct.** It is a hard dependency of `default_config`, is `integration_type: system` with `config_flow: false`, and re-creates its own config entry through `SOURCE_SYSTEM` — deleting that entry in the UI achieves nothing. Its python dependency (`go2rtc-client`) still reaches the environment through `default_config`; verified via `systemd.services.home-assistant.environment.PYTHONPATH`, **not** `services.home-assistant.package`, which is the un-overridden option and always looks empty. On a non-docker install with no configured URL, `go2rtc` removes its own entry and returns `True`, so it self-disables cleanly.

### ha-mcp (`_ha-mcp.nix`)

An MCP server that exposes HA as an *administration* API — ~87 tools covering automations (incl. traces and blueprint take-control), scripts, scenes, helpers, dashboards, the entity/device registries, history and templates. Distinct from core's `mcp_server` integration, which only re-exports the Assist intent API (device control, scoped to exposed entities) and is not installed.

Upstream ships it as two halves, and **the two halves are owned by different parties**:

- **`ha-mcp-tools`** — the `ha_mcp_tools` custom component from `homeassistant-ai/ha-mcp-integration` (the HACS mirror repo; the main `ha-mcp` repo vendors the same tree, but installing from there confuses HACS's version display, which is moot here). The only thing `_ha-mcp.nix` still packages. Every name in its `dependencies` is a `manifest.json` requirement, checked at build time by nixpkgs' `manifestRequirementsCheckHook` — `ruamel.yaml`, `voluptuous-openapi`, and since **2.2.0** also `mcp>=1.24.0`. That `mcp` is the *shared* copy; the server vendors its own under `ha_mcp/_vendor/mcp`, so do not "simplify" it away.
- **`ha-mcp`** — the server itself, the `ha-mcp` PyPI distribution, run **in process** inside HA's interpreter by the component's "HA-MCP Server" config entry. So it has to be in HA's python environment, which it reaches through the component's `dependencies` → `propagatedBuildInputs` → the module's `extraPackages` (home-assistant.nix line 134 upstream). **This is nixpkgs' `python3Packages.ha-mcp`** (maintainer `jamiemagee`), not ours — we had a duplicate derivation until nixpkgs picked the package up. Verify it landed via `systemd.services.home-assistant.environment.PYTHONPATH`, not `services.home-assistant.package`.

**`skip_pip` is what makes this declarative.** Upstream normally pip-installs the server and auto-updates it every 6h. `embedded_server.py`'s `_async_ensure_package` checks `hass.config.skip_pip` first — which the NixOS module always sets — and switches to `_async_externally_managed_package_version`, which only reads `importlib.metadata.version("ha-mcp")` and mutates nothing. The `update` entity correspondingly drops `UpdateEntityFeature.INSTALL` and tells you to update through the system package manager. The channel / auto-update / pip-spec options in the integration's UI are inert; **the server version is whatever nixpkgs ships.**

Version coupling worth knowing:

- **The component gates forward but not backward, and nothing warns about the backward case.** The server declares `MIN_COMPONENT_VERSION` (`tools/tools_filesystem.py`, `"1.2.0"` at both 8.4.3 and 8.5.0) and the component raises the `component_outdated` / `server_update_held` repair issues when *it* is the older half. There is **no** signal for the reverse — a component that outruns nixpkgs' server just fails at server start with an `ImportError` from `embedded_server.py`. Since `update-system` bumps the component while nixpkgs bumps the server, **check the component's `from ha_mcp …` imports against the server nixpkgs currently ships on every component bump**; most but not all are wrapped in `try/except ImportError`. (Verified for 2.2.0 ⇄ 8.4.3: all resolve.)
- The component also gates on `MIN_EMBEDDED_HOME_ASSISTANT_VERSION` (2026.8.0 at 2.2.0).
- **As of server 8.5.0 upstream vendors `fastmcp`, `mcp`, `mcp_types` and `websockets`** (`_vendor/`, `fastmcp-slim==4.0.3`) so HA Core's own pins cannot conflict, and its `Requires-Dist` swapped `fastmcp` for that library's ~27 runtime deps — including `httpx2`, which is a *separate* dist from `httpx` (module `httpx2`, no collision). nixpkgs' 8.4.3 predates this and still depends on `fastmcp` 3.4.7. When nixpkgs bumps to 8.5.0 its dependency list has to be rewritten wholesale; that is a nixpkgs problem now, not ours.
- The shared `websockets` is in HA's environment regardless (via `mcp`/`fastmcp` and ~20 integration libraries) — ha-mcp's vendoring only keeps *it* off that contested copy. Do not read the vendoring as a claim that the shared one is absent.
- The HACS-related modules (`install_source_check.py`, `hacs_nudge.py`) both read `hass.data["hacs"]` and no-op when it is absent, so a Nix install files no repair issues.

**Networking**: the in-process server's primary route is a Home Assistant webhook on port **8123**, which is already open. It *also* binds a direct listener on `0.0.0.0:9584` (`DEFAULT_SERVER_PORT`), gated behind a random secret path — that port is **not** opened in `raspi.nix`, so the direct URL shown on the entry's Configure screen is unreachable from the LAN by design. Prefer the webhook URL with `ha_auth`; open 9584 only if the direct listener is actually wanted.

`webhook` is in `_components.nix` because the manifest hard-depends on it (it also arrives transitively via `mobile_app`, but per the rule above every integration in use is named).

### Keeping the pins current (`pins.nix`)

Dropping HACS also dropped its update notifications. Only two things still self-report: the **ha-mcp server**, whose coordinator polls PyPI every `UPDATE_CHECK_INTERVAL` (6h) and is *not* gated on `skip_pip`, so its `update` entity still shows installed-vs-latest (just with no Install button) — which now tells you **nixpkgs** is behind, since the server is no longer a pin of ours; and `component_outdated`, a repair issue raised when the installed server needs a newer `ha_mcp_tools` than is running. Nothing watches the other 12 pins.

`pins.nix` re-exports all 13 HA pins as `packages.hass-*` solely for `nix-update`; the HA module still callPackages the same files directly. `update-system` stage [2/4] updates these alongside `ollama-darwin-source`. `--skip-pins` skips both groups. Every HA pin retains `--build`; Ollama uses a native source-only fetch and builds its binary package only on Darwin.

Three optional `passthru` knobs, read by that stage:

| knob                 | why                                                                                                                          |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `updatePolicy`       | `"stable"` (default) follows releases; `"branch"` follows default-branch HEAD, for the 3 cards + snapmaker_u1 (never tagged) |
| `updateFile`         | repo-relative path, forced via `--override-filename`                                                                         |
| `updateVersionRegex` | rejects tags upstream publishes but we don't want                                                                            |

**`buildHomeAssistantComponent` needs `updateFile`.** It goes through `lib.extendMkDerivation`, which relocates the derivation's position info into nixpkgs' own `build-custom-component/default.nix`; nix-update then throws `… is not in /nix/store/…-source` (`eval.nix:77`) rather than edit a path outside the flake. Both `_ha-mcp.nix` and `_berlin-transport.nix` set it.

**`ha_mcp_tools` needs `updateVersionRegex`.** Upstream tags a continuous stream of `v2.1.4-dev.NNN` prereleases beside its stable tags and nix-update takes the newest parseable tag — without the regex it lands on a dev build. Note the regex runs against the **raw tag**, before the `v` is stripped, so it must be `^v?(…)$`.

**How nix-update edits these, and the two rules that follow.** It anchors the target file on `unsafeGetAttrPos "src"`. Measured across all 11: the *file* is right everywhere, the *line* is wrong for 10 — `mkCard`/`mkTheme` report their own `inherit` line for every package they build, and `extendMkDerivation` points into nixpkgs. `update.py:36-58` handles that by checking whether the recorded line actually contains the old version and, when it doesn't, falling back to a **whole-file** string replace. Rev replacement is whole-file *unconditionally, and runs first*. So:

- **Every version and tag string must stay unique within its file.** Verified clean today; `_themes.nix` is closest to the edge with `"1.4"` and `"1.3"`. Prefer one pin per file for anything new rather than growing `_lovelace-modules.nix` (6) or `_themes.nix` (3).
- **Never embed the rev in the version string.** A `"branch"` pin must be `0-unstable-<date>` with the **full** rev. With `0-unstable-1a80547` the global rev replacement rewrites the short rev inside the version first, the version substitution then no longer matches, and you get `version = "0-unstable-1a805470152c86d9351abc7b0b56ef3ecb7e3a39"`. This is why the commit-pinned pins (three cards, `snapmaker_u1`) are date-versioned.

`update-firefox` and `update-thunderbird` are **not** replaceable by this: Firefox extensions are `ExtensionSettings` policies with an `install_url` that Firefox fetches at runtime (no Nix fetch, no hash at all), and Thunderbird's come from the AMO API, which nix-update has no version source for.

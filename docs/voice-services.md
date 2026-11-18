# Voice services reference

The [macmini host reference](system.md#macos-nix-darwin-host--macmini) owns launchd daemon setup, model loading, and logging failure modes.

All services here run on `macmini` except the Laya client, which is a Home Assistant component on the Pi. Hermes primary models are selected per host and profile in `modules/services/hermes-agent/_models.nix`, with ordered fallback chains in `_fallbacks.nix`; macmini uses loopback Ollama for both.

## Laya

A local fast path for voice commands in front of the Ollama conversation agent. It has three parts:

- **Server** (`modules/services/laya/laya.nix`): `laya.serve` as a launchd daemon on port 8000. It is LAN-reachable with no auth on purpose, because it can only score questions and never acts. `LAYA_REVISION=reviewed` keeps weights tied to the package version.
- **Translator** (`modules/services/libretranslate/libretranslate.nix`): LibreTranslate with en and pt only, on port 5001 with no auth. Port 5001 avoids the macOS AirPlay listener on 5000; leave AirPlay alone. Argos derives every path from `HOME` and `XDG_*_HOME`, so all of them must point into the state directory or models land in the wrong place. The `flask-swagger-ui` override exists because the pinned nixpkgs recipe still calls a `setup.py` that upstream removed.
- **Client** (`modules/services/home-assistant/laya/`): our own HA conversation agent, domain `laya`. It is written from scratch because the upstream `home-assistant-jev`/`-laya` retrieval breaks on pt-BR. Anything uncertain, any question, and any multi-step request goes unchanged to the fallback (Ollama) agent. Laya being down also escalates.

The server and translator URLs live in the HA config entry. After changing a port, reconfigure the existing entry; the reconfigure flow keeps the entry identity and options.

### Pipeline rules

`pipeline.py` documents its own design. Keep these properties when changing it:

- Laya only chooses among given options; it never generates. Numbers come from the text, and the chosen action decides what a number means.
- Keep each choice small. Round 2 asks the verb question twice with options reversed, and both answers must agree.
- Option keys are human-readable labels, since Laya reads `"key: description"`. `Planner._ids` maps answers back to ids.
- The device is grounded in the text through entity and area names and aliases, never chosen by the model alone. Aliases are what make pt-BR work: an entity without a Portuguese alias is reachable only in English.
- Translation feeds the model, never the grounding. Names and numbers are matched against what was said, and against the translation only when the original names nothing.
- The request language comes from the Assist pipeline, not from detection. This needs one Assist pipeline per language (EN, BR) with conversation language `*`. The fallback LLM always gets the original words.
- Yes/no questions are badly calibrated on this model. Use choices for anything that matters.
- Area-wide requests ("all the lights") escalate.

### Evaluation

`modules/services/home-assistant/laya-eval/eval.py` runs the same `pipeline.py` against a live server; its docstring and `--help` cover the flags. WRONG (an action taken that should not have been) is the number that matters; escalations only cost latency. Before enabling Laya in an Assist pipeline, measure on the macmini with `--url http://macmini.local:8000` and `--translate http://macmini.local:5001`, and require zero WRONG. `cases.json` is a small set, so grow it before trusting a zero.

Dump the HA snapshot fresh into a temp file each run, and include each exposed entity's registry aliases. A snapshot without aliases understates both languages.

## Open WebUI

Open WebUI listens on `0.0.0.0:8080`, LAN-bound with password authentication. LAN HTTP does not encrypt passwords or conversations.

- **`STATIC_DIR` must be redirected.** Its default sits inside the read-only store path, and open-webui copies assets into it on every start. `DATA_DIR`, `HF_HOME`, and `SENTENCE_TRANSFORMERS_HOME` live under `/var/lib/open-webui` for the same reason.
- **`HOST` and `PORT` are not environment variables.** `serve` takes them as CLI options, and `env.HOST` is silently ignored. Pass the bind address with `--host`.
- **`ENABLE_PERSISTENT_CONFIG = "False"` keeps the Nix authoritative.** With the default, the database overrides the environment after first boot. The trade is that settings changed in the admin UI do not persist; declare them in Nix.
- **Routing.** Two OpenAI-compatible connections point at loopback Hermes `/p/augusto/v1` and `/p/livia/v1`, giving models `augusto.hermes-agent` and `livia.hermes-agent`. Direct Ollama access is off. Keys enter only the runtime environment, never plists or store paths.
- **Fail-closed bootstrap.** The start wrapper waits for the signing secret, both initial passwords, and both Hermes profile keys. `_bootstrap.py` refuses to run while an old listener is up, backs up the database to `webui.db.pre-hermes.bak`, migrates, and reconciles accounts. Augusto keeps a fixed UUID and history as `augusto@localhost`; Livia is an ordinary user, `livia@localhost`. An identity journal makes bootstrap resumable without resetting later password changes. Any missing credential or identity conflict keeps the listener down.
- **Private models.** Each base model belongs to its user, with no access grants, and admin bypasses are off. This separates the two people inside the app only. Augusto remains the server administrator, and WebUI still lets admins call other models through its API. Livia must stay denied Augusto's model.
- **System-level sops.** This aspect imports `sops-nix.darwinModules.sops` for all of macmini and points `age.keyFile` at the key the Home Manager `secrets` aspect provisions. Hermes secrets depend on that import. Activation therefore depends on a path inside the user's home.

### Tools

Tools are rows in WebUI's `tool` table. `_tools.nix` pins their sources, and the `open-webui-tools` daemon imports them through the authenticated API.

- **The attr name in `_tools.nix` is the tool id**, the table's caller-supplied primary key. It must equal the installed row's id, or a duplicate tool appears. Ids must be lowercase Python identifiers, so `ask-user` becomes `ask_user`.
- **The API enforces upsert.** `create` rejects an existing id and `update` rejects a missing one, so the importer lists ids and picks the matching call. `update` never writes `valves`, so tool configuration survives. `specs` and the manifest are re-derived from source on every write.
- **The importer mints its own session token.** It signs with `WEBUI_SECRET_KEY` and reads the admin id and current `session_stamp` read-only from SQLite. Password changes invalidate older tokens even without Redis.
- **Frontmatter pip installs are off**, because they would install into the read-only store. Supply a tool's `requirements` through the package's Python environment instead, as `osm` does.

## Hermes Agent

On macmini, the `hermes-agent` aspect (`_darwin.nix`) runs one boot-time system LaunchDaemon as `augusto`. It bootstraps household profiles, then starts the shared Home Manager `hermes` wrapper with `-p default gateway run`. The wrapper uses upstream's Nix `messaging` package. `gateway.multiplex_profiles=true` serves the independent `augusto`, `livia` and work profiles under `/Users/augusto/.hermes/profiles/`. The daemon gets a sanitized environment so it never inherits ambient cloud credentials. The only user LaunchAgents are the wiki sync agents (see [LLM wiki](#llm-wiki)).

The `hermes-work` Home Manager aspect installs Hermes Desktop and Office 3D on both hosts. Desktop backend selection remains separate from the household gateway configuration. See [Work Hermes](coding-agents.md#work-hermes-laptop-and-macmini) for engineering profiles, the model map and host execution boundaries.

### Profiles and bootstrap

`_bootstrap.py` runs before each gateway start, followed by the wrapper's `_bootstrap_work.py`:

- Household bootstrap merges Nix-owned settings into each existing YAML and `.env`, preserving channel tokens, sender allowlists, and other local settings. Model records come from `_models.nix` and replace stale provider settings. Malformed YAML fails closed without being overwritten. The `API_SERVER_*` keys are Nix-owned; work bootstrap preserves the root listener.
- Household bootstrap adds Nix plugins to `plugins.enabled` without removing unrelated locally enabled ones. `_darwin.nix` owns their links and consent, including hwiki, the wiki gate, advanced delegation, Home Assistant and Office 3D. Bootstrap removes the old Ponytail link and disables that plugin while preserving unmanaged directories. rtk's `rtk-rewrite` rewrites household `terminal` commands before Hermes's dangerous-command check, as it does for the work profiles. See [Coding agents](coding-agents.md#rtk-shell-output-compression).
- It writes a mode-0600 `SOUL.md` into each profile: `modules/services/hermes-agent/SOUL.md`, that person's wiki section from `souls/_wiki.md`, and the local Caveman and Ponytail rules from `agent-shared/style/`. Local edits are replaced on the next start. Edit the tracked files, rebuild, and start a fresh chat.
- Each profile loads the shared development skills and the same `disabledSkills` as the work profiles, so coding here behaves like work.
- Each profile gets its own SOPS-managed API key. Memories, sessions, skills, and cron state stay per profile. Missing credentials block startup.

The household migration regression runs with the Hermes venv Python: `python -m unittest discover -s modules/services/hermes-agent/tests -v`. For deployment checks, render the macmini household manifest and run `_bootstrap.py` twice in an isolated `HERMES_HOME`; confirm both SOULs contain the local rules and unrelated plugins and manual skills survive.

Only the host config enables the API listener on `127.0.0.1:8650`. Profile endpoints are `/p/augusto/v1` and `/p/livia/v1`. Their `/models` responses advertise profile names, so WebUI connections must declare `model_ids=["hermes-agent"]` explicitly.

### Operating

- Configure channels with `hermes -p <person> gateway setup` and pair WhatsApp with `hermes -p <person> whatsapp`. Use the systemwide CLI; keep the single system LaunchDaemon rather than installing a user gateway.
- After changing channel settings, run `sudo launchctl kickstart -k system/org.nixos.hermes-agent`.
- After a model change, rebuild, restart the affected services, and start a fresh Hermes conversation.
- HA's own Ollama conversation and AI-task models are UI-managed config subentries outside this repo. Check them separately.
- Hermes and uv2nix track upstream default branches through unversioned GitHub inputs. `nix flake update` advances them; `flake.lock` holds the exact revisions. `hermes-plugin-hwiki` is pinned to the commit in Hermes's plugin catalog; move it by hand when the catalog does.

### LLM wiki

The shared wiki design (gate, terminal gap, sync audit, vault checkout) is in [Coding agents](coding-agents.md#llm-wiki). This section covers the macmini's side.

- **Profiles.** `augusto` files sources into the `home` tree of Augusto's vault and `livia` into the `livia` tree of her own vault. Each hands ingest, verdicts, apply and lint to its librarian through a profile route: `librarian` and `librarian-livia`, both defined in `_work.nix` from `_wikis.nix` and served by the same gateway. The librarians have no WhatsApp chat. Their digests and weekly `memory/` reports arrive in each librarian's Bot Chat in the macmini's Hermes Desktop and in any channel connected to it at runtime, such as a Telegram bot set up by hand; Augusto and Livia reply there with verdicts (see [Delivery](coding-agents.md#llm-wiki)).
- **hwiki** is the memory provider for both household profiles and both librarians. `_darwin.nix` owns the household profiles' `hwiki.json`; recall treats every `raw/` and `review/` folder as untrusted.
- **Livia's vault** stays on the macmini with local Git history and no remote. The `wiki-vaults` activation runs `git init` on it, and the first sync writes its baseline. Livia files sources through her WhatsApp profile and reviews digests from `librarian-livia` in its Bot Chat or connected channel; Obsidian is configured for Augusto's vault alone.
- **Sync** runs one launchd agent per tree, `wiki-sync-home` and `wiki-sync-livia`. Failures reach the tree's librarian through its `wiki-sync-report` cron.

### Secrets

Static channel credentials such as Telegram bot tokens belong in SOPS, wired to the owning profile in `hermes-agent.nix`. Adding an encrypted key alone does not inject it. Credentials created by the setup wizard stay in that profile's private `.env` until wired. WhatsApp session state stays in the profile's private `platforms/whatsapp/session`, never in a derivation or the repo.

### MCP servers

Both household profiles get Context7 through its anonymous public endpoint, with `trust: untrusted`. Tools without a read-only annotation need approval and unattended calls fail closed. Open WebUI's chat route cannot answer approvals.

### Home Assistant

The official Home Assistant plugin is installed for macmini's household and work profiles. Its tools are enabled for `augusto`, `livia` and `coordinator`. Nix sets `HASS_URL`; authentication requires a long-lived `HASS_TOKEN` in each authorized profile's private `.env`. Bootstrap preserves that token. No token is currently provisioned by Nix; installation alone does not authenticate the plugin.

These are native REST tools, not MCP tools, so Context7's approval policy does not govern service calls. Upstream blocks dangerous service domains, but ordinary device-control services remain available to authorized profiles. No event-watch domains or entities are configured.

### Latency

Separate startup, memory retrieval, model scheduling, prompt processing, and output generation. With cloud generation models, prompt processing and output run on ollama.com. If a model is switched back to a local one, a large Hermes prompt is slow to process on this host, and the MLX runner serializes requests, so background work such as librarian cron runs delays foreground chat. See [MLX scheduling](system.md#macos-nix-darwin-host--macmini). Collect metadata-only timing; raw prompts, messages, and credentials can contain private data.

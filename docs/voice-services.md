# Voice services reference

The [macmini host reference](system.md#macos-nix-darwin-host--macmini) owns launchd daemon setup, model loading, and logging failure modes.

All services here run on `macmini` except the Laya client, which is a Home Assistant component on the Pi. Generation for Hermes and Honcho goes to loopback Ollama using `services.ollama.model` from `modules/services/ollama/ollama.nix`. Change the model there, not in each consumer.

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
- **System-level sops.** This aspect imports `sops-nix.darwinModules.sops` for all of macmini and points `age.keyFile` at the key the Home Manager `secrets` aspect provisions. Hermes and Honcho secrets depend on that import. Activation therefore depends on a path inside the user's home.

### Tools

Tools are rows in WebUI's `tool` table. `_tools.nix` pins their sources, and the `open-webui-tools` daemon imports them through the authenticated API.

- **The attr name in `_tools.nix` is the tool id**, the table's caller-supplied primary key. It must equal the installed row's id, or a duplicate tool appears. Ids must be lowercase Python identifiers, so `ask-user` becomes `ask_user`.
- **The API enforces upsert.** `create` rejects an existing id and `update` rejects a missing one, so the importer lists ids and picks the matching call. `update` never writes `valves`, so tool configuration survives. `specs` and the manifest are re-derived from source on every write.
- **The importer mints its own session token.** It signs with `WEBUI_SECRET_KEY` and reads the admin id and current `session_stamp` read-only from SQLite. Password changes invalidate older tokens even without Redis.
- **Frontmatter pip installs are off**, because they would install into the read-only store. Supply a tool's `requirements` through the package's Python environment instead, as `osm` does.

## Honcho

The `honcho` aspect runs native PostgreSQL 17 with pgvector, the Honcho API on `127.0.0.1:8001`, and one deriver worker. The Python environment is built with uv2nix from the locked source, sharing the builder with Hermes.

PostgreSQL has no TCP listener. Peer mappings let `_postgres` bootstrap as `postgres` and `augusto` connect as non-superuser `honcho` to database `honcho` only. Unexpected ownership, privileges, or major version fail closed. Initialization never overwrites a nonempty directory.

**The database must be UTF-8.** macOS with locale `C` otherwise defaults to `SQL_ASCII`, and psycopg then breaks the extension checks. Bootstrap and API readiness reject an existing non-UTF-8 database. Never reinitialize a populated store. To repair an empty failed first deployment: stop the API, worker, and Hermes; rename the old database as a rollback copy; create the UTF-8 replacement and extensions; then restart those jobs. This needs privileged PostgreSQL access.

API startup checks that the local embedding model returns 1024 finite numbers, runs migrations, then sets the vector dimension on empty tables. Populated embeddings cannot be resized, so changing the embedding model or its dimension needs a memory migration. The worker creates workspaces `hermes-augusto` and `hermes-livia`, persists scoped keys under `/var/lib/honcho/app/keys`, and verifies cross-workspace rejection before deriving.

`DERIVER_MODEL_CONFIG__THINKING_EFFORT=none` is required: with thinking on, fact extraction spends its output budget on reasoning and returns no JSON. `honcho_jwt_secret` is SOPS-managed and readable by `augusto`. Admin JWTs are transient bootstrap credentials, never profile credentials.

### Diagnosing empty memory

Check these separately: persisted message counts, `GET /v3/workspaces/{workspace_id}/queue/status`, conclusion counts, and terminal queue errors. Terminal failures are marked processed, and restarting the worker does not replay them. To recover, fix the cause first. Then reset the processed and error fields of only the specific failed queue rows, after checking their workspace, task type, message ids, and failure. Do not resend introductions or reset unrelated queue rows.

`hermes -p <person> honcho status` shows peer cards and a representation preview, not the full stored conclusions. Cards come from a later dream stage that needs many observations and session inactivity. An empty card alone does not prove ingestion failed.

## Hermes Agent

The `hermes-agent` aspect runs upstream's Nix `messaging` package as one boot-time system LaunchDaemon, `hermes gateway run` as `augusto`. Upstream's Home Manager module installs a LaunchAgent instead, so only service and profile glue is local. `gateway.multiplex_profiles=true` serves the independent `augusto` and `livia` profiles under `/Users/augusto/.hermes/profiles/`. The daemon gets a sanitized environment so it never inherits ambient cloud credentials.

### Profiles and bootstrap

`_bootstrap.py` runs before each gateway start:

- It merges Nix-owned settings into each existing YAML and `.env`, preserving channel tokens, sender allowlists, and other local settings. Malformed YAML fails closed without being overwritten. The `API_SERVER_*` keys are Nix-owned.
- It adds Nix plugins to `plugins.enabled` without removing locally enabled ones. Linked plugins include the Honcho directory plugin, Ponytail, and rtk's `rtk-rewrite`, which rewrites `terminal` commands before Hermes's dangerous-command check runs. See [Coding agents](coding-agents.md#rtk-shell-output-compression).
- It links the Caveman skill bundle as `skills/caveman-bundle`. Learned skills stay writable outside it, and bootstrap refuses to replace an unmanaged directory at a managed link path.
- It writes a mode-0600 copy of `modules/services/hermes-agent/SOUL.md` into each profile. Local edits are replaced on the next start. Edit the tracked file, rebuild, and start a fresh chat.
- Each profile gets its own SOPS-managed API key and Honcho workspace key. Memories, sessions, skills, and cron state stay per profile. Missing credentials or failed Honcho access block startup.

Only the host config enables the API listener on `127.0.0.1:8650`. Profile endpoints are `/p/augusto/v1` and `/p/livia/v1`. Their `/models` responses advertise profile names, so WebUI connections must declare `model_ids=["hermes-agent"]` explicitly.

### Operating

- Configure channels with `hermes -p <person> gateway setup` and pair WhatsApp with `hermes -p <person> whatsapp`. Use the systemwide CLI; keep the single system LaunchDaemon rather than installing a user gateway.
- After changing channel settings, run `sudo launchctl kickstart -k system/org.nixos.hermes-agent`.
- After a model change, rebuild, restart the affected services, and start a fresh Hermes conversation.
- HA's own Ollama conversation and AI-task models are UI-managed config subentries outside this repo. Check them separately.
- Hermes, Honcho, the Honcho plugin, and uv2nix track upstream default branches through unversioned GitHub inputs. `nix flake update` advances them; `flake.lock` holds the exact revisions.

### Secrets

Static channel credentials such as Telegram bot tokens belong in SOPS, wired to the owning profile in `hermes-agent.nix`. Adding an encrypted key alone does not inject it. Credentials created by the setup wizard stay in that profile's private `.env` until wired. WhatsApp session state stays in the profile's private `platforms/whatsapp/session`, never in a derivation or the repo.

### MCP servers

Both profiles get Context7 (anonymous public endpoint) and the Home Assistant MCP server over its authenticated webhook. `hermes_home_assistant_mcp_url` and `hermes_home_assistant_token` hold the webhook URL and a dedicated long-lived token named `Hermes Agent`, owned by the `HA-MCP Server` admin account and revocable there. Bootstrap renders them only into each profile's private `.env`, never the store or the host profile. Both profiles share this household access. The connection is HTTP on the trusted LAN; never expose it or its credentials to untrusted networks.

Reference these credentials as `${HERMES_HOME_ASSISTANT_MCP_URL}` and `${HERMES_HOME_ASSISTANT_TOKEN}`. The `${env:NAME}` form triggers a false warning because the config loader runs before the profile `.env` loads.

Both servers use `trust: untrusted`, so tools without a read-only annotation need approval and unattended calls fail closed. Open WebUI's chat route cannot answer approvals; make HA changes from an approval-capable Hermes surface.

### Latency

Separate startup, memory retrieval, model scheduling, prompt processing, and output generation. A Hermes request carries a large prompt, so prompt processing alone is slow on this host. Honcho's background dialectic and derivation cycles also call the model, and the MLX runner serializes requests, so background memory work delays foreground chat. See [MLX scheduling](system.md#macos-nix-darwin-host--macmini). Collect metadata-only timing; raw prompts, messages, credentials, and Honcho request URLs can contain private data.

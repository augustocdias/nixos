# Coding agents reference

Read before changing harness prompts, settings, extensions, skills, models, MCPs, approvals, or the sandbox. [Herdr](herdr.md) owns terminal lifecycle and sidebar integration. Source files remain authoritative for current values; historical version observations below are not fresh compatibility checks.

## Coding agents: omp and Claude Code

- **omp** (oh-my-pi) — personal harness, laptop and macmini (`user-base`); not installed on raspi. Work MCPs included, since the company now allows OpenAI models.
- **Claude Code** — work harness, laptop only (pulled in by the `work` aspect).

### Shared pieces (`modules/programs/agent-shared/`, `modules/programs/agent-jail/`)

| Path                                  | Contents                                                                                                             |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `agent-shared/_lib.nix`               | descriptions + `withFrontmatter`: prompt bodies are frontmatter-free, each harness renders its own frontmatter keys  |
| `agent-shared/context.md`             | global instructions (both harnesses' `context`)                                                                      |
| `agent-shared/style/`                 | chat-style and engineering rules adapted from Caveman/Ponytail, appended to the context; credits in `third-party/`  |
| `agent-shared/agents/`                | shared `test-writer` body                                                                                            |
| `agent-shared/commands/`              | shared `/commit` body                                                                                                |
| `agent-shared/skills/`                | all shared skills: 26 curated Matt Pocock skills plus local `git-conventions`, companions, license, provenance, workflow |
| `agent-shared/_skills.nix`            | one source bundle; copies the shared `WORKFLOW.md` into every installed skill root                                      |
| `agent-shared/_bash.nix`              | `{jailed}:` bash ruleset (pattern → allow/ask/deny), translated by each harness's `_permissions.nix`                 |
| `agent-jail/_mk-jail.nix`             | `mkJail {name, package, pre, extra}` — the bubblewrap jail; `pre`/`extra` are functions of jail-nix's combinator set |
| `agent-jail/jail-context.md`          | instructions loaded **only** inside the sandbox (both harnesses)                                                     |
| `agent-jail/_host-query/`             | host-side service backing the `host_*` tools (`agent-host-query`)                                                    |
| `agent-jail/host-mcp.py`              | stdio MCP shim exposing `host_*` to both harnesses (dependency-free JSON-RPC → host-query over loopback)             |
| `agent-jail/_herdr-relay/`            | host-side allowlisting relay standing in for the herdr socket (sidebar + lifecycle + resume reports only)            |

`_`-prefixed files are skipped by import-tree and imported by hand.

### Development skills

Both harnesses install the same 26 curated skills from `mattpocock/skills` revision `a496f5513d4a4cf889bc48e189e579f4b0bdf6aa`, without a new flake input. The original baseline was `5beb35b040e3de97e54fa9e386d7e42d15c295c2`; the `v1.3.1` tag is not either immutable revision. Excluded skills remain excluded; setup is renamed `setup-dev-skills`. Updates are deliberate copy-and-review operations recorded in `third-party/mattpocock-skills/UPSTREAM.md`. The same folder holds the local `git-conventions` skill.

Manual-only (14): `grill-me`, `grill-with-docs`, `setup-dev-skills`, `implement-spec`, `improve-codebase-architecture`, `retro`, `to-spec`, `to-tickets`, `triage`, `wayfinder`, `handoff`, `teach`, `to-questionnaire`, `wait-what`.

Contextual and manually invocable (12): `implement`, `code-review`, `codebase-design`, `diagnosing-bugs`, `domain-modeling`, `pr`, `prototype`, `research`, `tdd`, `wizard`, `grilling`, `writing-for-agents`. Invoke `implement` manually with Claude `/implement` or omp `/skill:implement`, or contextually for user-requested implementation and explicit orchestrator assignments.

Claude uses native Skill invocation and `/name`; omp uses `read skill://name` and explicit `/skill:name`. Manual flags constrain invocation, not approvals. Each installed root includes `WORKFLOW.md`, so companion reads require no parent traversal. Licenses and attribution live only in `third-party/` and are not installed.

Setup initializes `.dev-skills/` in the invocation directory, writes shared tracker/domain/standards prerequisites, and adds one local `info/exclude` rule. Other skills reuse the nearest initialized workspace within the current checkout. New supporting artifacts stay there; existing authoritative tracked documents remain intact. Ignoring is not encryption or backup, and local documents need explicit sharing.

`code-review` owns configured diff review; `pr` owns PR bodies with repository-template precedence; manual `to-spec` and `to-tickets` own their workflows. Native omp `/review` and reviewer remain. `git-conventions` owns an upfront agreement for branch, worktree, commit, push and PR ownership (agent-owned, ask each time or human-owned). Read-only discovery needs none. Existing approvals remain mandatory; routine delegation never authorizes published rewrites, merging PRs, destructive cleanup or repository-setting changes.

`implement-spec` delegates a fresh `implement` agent per ticket, including a single ready ticket. Authorized distinct worktrees permit independent frontier tickets concurrently; otherwise children run sequentially in the current checkout. The parent owns credentials, signed commits/pushes through Linux `host_exec`, refs, tracker writes and shared progress. Required SSH approval precedes any subagent. Dependencies use verified implementation/commits, not remote closure. Small parent-relative PRs/stacks replace aggregate PRs; whole-spec integration may be local-only. Versioned mechanics live in `implement-spec/STACKS.md`.

Default run worktrees live under the parent's absolute `.dev-skills/worktrees/<run>/<ticket>`. Delegates explicitly receive that supporting workspace even outside their own Git roots; they write distinct evidence, not duplicate setup or shared progress. Required ignored inputs must be verified; never blindly copy secrets. One writer owns each checkout. Quiesce workers before ref changes; clean only authorized clean run-created worktrees non-forcibly.

Supporting artifacts, local progress and temporary prototype wiring never enter implementation commits or pushes. Stage explicit production paths; tracked/staged `.dev-skills/` artifacts block publication without automatic untracking/discard. Authorized remote summaries contain concise evidence, not uploaded files or inaccessible local links. Prototype variants may use real routes and promote the selected design within scope, while sources/captures remain local. Workspace glossary updates happen inline; existing tracked domain documents remain authoritative unless their edits are explicitly requested. Generated wizards remain human-run on the host.

Wizard GitHub writes require an explicit repository, passed to `gh` independently of the caller's cwd or shell export state. Run `node --test modules/programs/agent-shared/skills-wizard.test.mjs` for the harmless targeting regression.

## Agent sandbox (Linux only)

On Linux `omp` and `claude` **are** the jail: `agent-jail/_mk-jail.nix` wraps the package with bubblewrap via the `jail-nix` combinator library and installs it under the original binary name. Darwin has no sandbox and relies on the allowlist alone.

Deny-by-default. Persistent writable areas: the working directory **at its real host path** (plus `git rev-parse --git-common-dir` when it differs, or git breaks outright in a linked worktree), `~/granted/*` (subject to each grant's requested read/write mode), the persistent caches (`~/.cache/nix`, `~/.npm`, `~/.bun`, `~/.cargo/{registry,git}`, `~/.local/share/direnv`, `~/.local/share/rtk`), and the harness's own state (omp: `~/.omp`; claude: `~/.claude`; both: `~/.cache/jgrep`). Everything else — `/`, `/etc`, `/tmp`, `$HOME` — is a per-session tmpfs that is silently discarded, so a successful write there proves nothing. State dirs are per-harness: `~/.local/share/<name>-jail/{grants,log}`.

Things that cost real time to discover:

- **bwrap sets `PR_SET_NO_NEW_PRIVS` unconditionally** (`bubblewrap.c` `main()`, dies if it fails), so setuid is inert and in-jail `sudo nixos-rebuild` cannot activate the host. This does not prohibit approved host execution or authorized remote deployment. A kernel property, not a permission rule.
- **`NIX_REMOTE=daemon` is mandatory.** bwrap's uid map makes the store look user-owned and tricks nix into single-user mode. `trusted-users = root` means a client cannot disable the build sandbox — which is *why* `nix build` is safe to allow in here.
- **No enumerated toolbelt.** `/nix/store` is bound read-only and `/run/current-system/sw` + `/etc/profiles/per-user/<user>` supply PATH, so the host toolchain works as-is. Curating a toolbelt would be tidiness, not a boundary: every store binary is reachable by absolute path regardless.
- **The host environment is inherited except terminal signing selection.** jail-nix's `base` ends with `--clearenv`, so we `reset` and rebuild its pieces without it — that is how sops-derived keys, `HERDR_*` and direnv's exports arrive. The first launcher runtime block removes `GPG_TTY` before `pre` and host-query startup; the final block adds `--unsetenv GPG_TTY` after caller overlays. DISPLAY/WAYLAND_DISPLAY remain intact. Restart existing sessions/helpers to pick this up. gpg-agent retains terminal/display state, so absence alone does not prove GUI pinentry; do not flush caches or restart the agent just to force a prompt. Consequence: `add-path` seeds from empty `state.env.PATH`, so use `set-env "PATH" "…:$PATH"`.
- **No gpg-agent signing socket.** The agent is a signing *and* decryption oracle: it would let the jail sign as the user and decrypt every sops secret (`env.yaml` lives in the repo). With `signByDefault = true` in the read-only git config, `git commit` fails for want of a signer — that failure **is** the approval gate, and committing goes through `host_exec`.
- **No SSH agent socket at launch.** `SSH_AUTH_SOCK` is unset inside (`--unsetenv`; the inherited host value would point at nothing). The agent requests it with `host_ssh_agent`, which prompts like every host tool. On approval host-query listens on `<grant_root>/ssh-agent.sock` and pipes each connection to the host's `S.gpg-agent.ssh` (passed as `HOST_SSH_AUTH_SOCK`) until host-query exits. It is a relay, not `host_mount`, because a socket seen through bindfs/FUSE cannot be `connect()`ed; the grant root is a plain bind, so the jail sees the real inode. `~/.ssh/known_hosts` stays read-only; private-key directories are not mounted. An unknown host requires the normal trusted-host/approval route, never weakened host verification. Consequential pushes and deletions retain their normal approvals; the SSH capability is not authorization. The separate signing/decryption socket remains absent.
- **Herdr is reached only through a relay, never the real socket.** Inside herdr (`HERDR_ENV=1`) the launcher starts `agent-jail/_herdr-relay` on the host, pinned to this pane's `HERDR_PANE_ID` and the harness `name`, in a private `mktemp -d /tmp/agent-herdr-relay.*` dir. Its socket is bound over `$HERDR_SOCKET_PATH` (and the canonical path if different) as the **last** runtime arg, so no caller overlay can re-expose the real one. It forwards exactly `pane.report_metadata` (both, `user:<name>-activity`, the seven sidebar tokens), `pane.report_agent` (omp only, `herdr:<name>`) and `pane.report_agent_session` (both), each re-serialized from validated fields; everything else — `pane.read`, `send_*`, `split`, `agent.*`, `ping`, events — is `relay_denied` without touching herdr. `resume_argv` is always refused, so resume can only be herdr's built-in `<agent> --resume <ref>`; session ids must match `[A-Za-z0-9][A-Za-z0-9_-]*`. A relay that fails to start aborts the launch (no fallback), and the launcher refuses a cwd/git-common-dir that contains the socket's directory. Outside herdr the relay is not started and `HERDR_SOCKET_PATH` is unset. `HERDR_AGENT` (herdr's wrapper hint) was considered and rejected: it only feeds screen scraping, while resume ids and sidebar tokens exist solely as socket reports. Tests: `python3 -m unittest discover -s modules/programs/agent-jail/_herdr-relay`, also run as the package's `checkPhase`.
- **`rm`/`rmdir` are rmtrash, and trash is per-mount.** Every writable path is its own bind mount, so the freedesktop spec picks that mount's own `.Trash-1000` — a rename into the home trash would be `EXDEV`. Deletions in the working directory therefore land in `<workdir>/.Trash-1000/`, which is why `programs.git.ignores = [".Trash-*/"]` exists. `~/.local/share/Trash` is deliberately **not** bound.
- **Already-running jails keep the old raw socket** until restarted. The `herdr*` bash `ask` rules stay as defense in depth; the herdr CLI inside the jail now just gets `relay_denied`.

### `host_*` tools

`host_exec`, `host_mount`, `host_journal` and `host_ssh_agent` are the jail's only route to the host, served by `agent-jail/_host-query` over loopback and exposed to both harnesses by `host-mcp.py`. Each harness prompts on every call. `host_exec` runs one command unsandboxed; `host_mount` bindfs-grants a host dir at `~/granted/<name>`; `host_journal` reads the journal with a fixed argv; `host_ssh_agent` relays the host SSH agent at `~/granted/ssh-agent.sock`.

`host_journal` exists because it is the *only* way to read the journal from inside: bubblewrap's user namespace cannot map supplementary groups, so the `wheel` membership the journal's ACL depends on is gone. Bash `journalctl` there prints "No journal files were found" and **exits 0**, which is a silent-success trap. Outside the jail `HOST_QUERY_PORT` is unset and all four tools short-circuit with an explanation.

## oh-my-pi (omp)

`modules/programs/omp/`, aspects `omp` (`user-base`) + `omp-jail` (`user-linux`). Upstream is a Bun + Rust fork of pi: hashline edits, an `lsp` tool, parallel `task` subagents, TTSR rules, a session tree, persistent Python `eval`. **No sandbox of its own** — its approval system is policy, not containment, and defaults to `yolo` — so on Linux it runs in the shared `mkJail`.

| File                            | Contents                                                                         |
| ------------------------------- | -------------------------------------------------------------------------------- |
| `omp.nix`                       | flake input (tag-pinned), wrapped package, settings, `mcp.json`, keys, prompts   |
| `_permissions.nix`              | `tools.approval*` + `bash.patterns`, built from `agent-shared/_bash.nix`         |
| `jail/jail.nix`                 | `mkJail` binding `~/.omp`, `~/.cache/jgrep`                                      |
| `extensions/gate.ts`            | approval for the work MCPs (see below)                                           |

- **Not the upstream HM module**: its `package` is not nullable (the jail installs `omp`) and it only writes `config.yml`.
- **Settings go through `PI_CONFIG_FILES`**, set by `wrapProgram`. omp rewrites `~/.omp/agent/config.yml` from `/settings` and migrations, so that file cannot be a store symlink. The env overlay is per-process, ranks above global *and project* config, and is never written back. Nix owns theme, `tui.vimMode`, update/telemetry switches, `extensions` and approvals; the rest of `config.yml` stays omp's. Overlays replace arrays rather than merging them, so the pinned empty `extensions` keeps a project from adding packages.
- **Everything else is `home.file`** under `~/.omp/agent/`: `mcp.json`, `keybindings.yml`, `AGENTS.md` (`context.md` + `jail-context.md` on Linux), `agents/`, `commands/`, `skills/`, `extensions/`. Read-only symlinks are fine because these files are only rewritten by `/mcp add|enable|disable`, which we don't use. Extensions load from store symlinks: the loader resolves realpath and Bun imports `.ts` directly; `@oh-my-pi/*` imports are redirected to the bundled copies, so no `node_modules`.
- **All runtime state is under `~/.omp`** (credentials and MCP OAuth tokens in `agent.db`, sessions, worktrees, extracted natives), hence the single rw bind. **No D-Bus in the jail**: the session bus reaches `systemd --user`, which can start units outside it. So omp's desktop notifications (`notify-send`/`gdbus`) are dead; it still emits in-band OSC 9/99 when it recognises the terminal (unverified under herdr), else a bare BEL. herdr's own state toasts are what actually signal completion and `blocked`.
- **Provider**: OpenAI, logged in at runtime (`/login openai-codex`). **Do not use `/login anthropic`**: it works by impersonating Claude Code's client.
- **Task isolation is pinned off** (`task.isolation.enabled = false`). omp's automatic per-task snapshots are not explicit permission-controlled Git worktrees. `implement-spec` assigns approved persistent worktrees itself; unrelated tasks do not enable automatic isolation.
- **Shared prompts**: `test-writer`, `/commit`, `git-conventions`, and the development skills above. omp has no `` !`cmd` `` injection, so command markers are stripped and the command is told to run them. No custom `/pr`, `reviewer`, or `/review` is installed; native omp `/review` and its schema-bound reviewer remain untouched.

### Approvals

- Jailed: `approvalMode = yolo`; `bash.patterns` = the jailed `_bash.nix` ruleset emitted **deny → prompt → allow**, because omp is first-match (lossless for the same reason as Claude's translation). Darwin: `approvalMode = write` plus the unjailed allowlist.
- `mcp__host_{exec,mount,journal}` are `tools.approval: prompt`. Explicit prompts hold even in yolo and never offer "approve for session".
- **Approval keys are exact names with no wildcards**, so the work MCPs (whose tool lists grow upstream) are gated by `gate.ts`: a `tool_call` handler that lets read verbs through (`get list search fetch query aggregate analyze`, after skipping `notion`/`calendar`/`datadog` nouns) and `ctx.ui.confirm`s the rest. Without a UI it blocks, so a subagent can never write to Linear/Notion/Datadog. Stricter than Claude, which fully allows Datadog.
- `eval` is not gated in the jail: it reaches no more than bash already can there.
- Subagents always run `yolo`, but `deny` and `prompt` still apply (a prompt rejects).

### Models

All OpenAI Codex; no local profile, no `models.yml`, no presets. Effort is the `:level` suffix. Abbreviated below: `sol` = `gpt-6.1-sol`, `astra` = `gpt-6-astra`, `luna` = `gpt-6-luna`.

| where                      | entries                                                                                                                                                                                                 |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `modelRoles`               | `default`/`task`/`advisor`/`memory` sol:medium; `plan` astra:high; `slow` astra:medium; `commit`/`tiny`/`widget` luna:low; `smol` luna:medium |
| `task.agentModelOverrides` | `task`, `tickets` sol:medium; `test-writer` sol:high; `reviewer`, `security-reviewer`, `troubleshoot` astra:high; `scout` luna:medium |

Session titles use the default `title.generator = fork`: a side turn on the session's main model names the initial title. `tiny` handles fallback generation and replan refreshes; `smol` also drives `edit.autoRepair`. `title.icons = boring` disables the icon and short-code prefix for newly generated or explicitly renamed titles; existing stored titles keep their prefix until renamed. Overrides win over agent frontmatter. The ids come from the bundled catalog, which Codex replaces with its live `/models` list after login, so a missing id surfaces as a role fallback in `/models`. Copilot is planned as `retry.fallbackChains.default`.

Startup: `plan.defaultOnStartup = false`; fresh sessions use `modelRoles.default` (Sol/medium), not native plan mode. Start on the slow role without changing the default with `omp --model @slow`; slow means the reasoning-model role, not provider flex billing. Explicit CLI model selection and session resume remain intact; the wrapper injects no `--model`. Manual `alt+p` and `/plan` remain available; grilling does not automatically enter native plan mode. `startup.setupWizard = false` because first-run choices are declared here. The overlay shadows stale user-level defaults; Claude startup is unchanged.

`tui.hyperlinks = "always"` forces OSC 8 links for paths and URLs instead of relying on terminal capability detection.

Also enabled beyond defaults: `advisor`, `astGrep`, `error.notify`, `autolearn`, `lsp.diagnosticsOnEdit`, `github`, `retry.usageAwareFallback`, `edit.autoRepair` and `checkpoint`. `bash.gitGuard = false` explicitly disables the boolean hard Git guard so skill ownership can permit branch switching; no replacement enforcement layer is added. Shared command permissions and host/SSH/MCP/Nix/Herdr approvals remain unchanged.

Memory is disabled with `memory.backend = "off"`: no memory backend runs. Existing Mnemopi data remains under `~/.omp`; disabling memory does not delete it. `autolearn` remains enabled for managed skills, independently of the memory backend.

### Status line

`statusLine.preset = custom`: left `pi vim model mode path git pr`, right `status usage context_pct` (omp's `default` minus `collab`/`stream`/`cost`, plus extension statuses and the ChatGPT plan quota). `showHookStatus = false` so extension stamps show only in the bar, not under the prompt.

### Keybindings (`keybindings.yml`)

Only omp's change. herdr owns `ctrl+g`, `ctrl+h/j/k/l`, `alt+m`, `alt+r`, `alt+d`; OmniWM (macOS) owns Option + `h/j/k/l`, `shift+h/j/k/l`, `f`, `shift+f`, `e`, `t`, `return` and the digits.

| action                         | now                            |
| ------------------------------ | ------------------------------ |
| `app.editor.external`          | `ctrl+e` (as in Claude)        |
| `tui.editor.cursorLineEnd`     | `end` (frees `ctrl+e`)         |
| `app.model.select`             | `alt+shift+m`                  |
| `app.retry`                    | `f5`                           |
| `app.plan.toggle`              | `alt+p`                        |
| `app.model.selectTemporary`    | `alt+shift+t` (frees `alt+p`)  |
| `app.live.toggle`              | `alt+v`                        |
| `app.ask.hide`                 | `alt+shift+a`                  |
| `app.display.reset`            | `alt+shift+r`                  |
| `app.clipboard.copyLine`       | `alt+shift+y`                  |
| `tui.editor.cursorWordRight`   | without `alt+f`                |
| `tui.editor.deleteWordForward` | without `alt+d`                |
| `tui.input.newLine`            | `shift+enter`                  |
| `tui.editor.deleteToLineEnd`   | unbound (vim `D`/`C` cover it) |

### Work (`modules/services/work/work.nix`)

`omp.mcpServers` (an option `omp.nix` declares and merges into `mcp.json`) adds Notion, Linear and Datadog as `type: http`. OAuth is `/mcp reauth <name>`; the callback listens on `:3000` inside the jail, which shares the host network. Datadog uses `/v1/mcp` in both harnesses. Notion and Datadog set `instructions = false` (see [Context budget](#context-budget)). Also `troubleshoot`/`tickets` agents (tools = `omp.readOnlyTools`) and the `datadog-queries`/`jgrep` skills. The omp `tickets` prompt gets a preamble: as a headless subagent it cannot write (the gate blocks without a UI), so it returns each mutation as a proposal — tool name plus arguments — for the parent session to perform behind the prompt.

## Claude Code

`modules/programs/claude-code/`, aspects `claude-code` + `claude-code-jail`, both included by `work` (laptop only). Configured through home-manager's `programs.claude-code`.

| File                     | Contents                                                                                        |
| ------------------------ | ----------------------------------------------------------------------------------------------- |
| `claude-code.nix`        | settings, permissions, MCP, agents, commands, skills, plugins, the herdr hook; `ponytail` input |
| `_permissions.nix`       | translates the jailed `agent-shared/_bash.nix` into `Bash(...)` allow/ask/deny lists            |
| `jail.nix`               | `mkJail` for `pkgs.claude-code`                                                                 |
| `agents/`                | work-only prompts: `troubleshoot` (Datadog), `tickets` (Linear/Notion)                          |
| `skills/datadog-queries` | work-only skill                                                                                 |

- **`CLAUDE_CONFIG_DIR=$HOME/.claude`** is set inside the jail so `.claude.json` lives *inside* the bound dir — Claude rewrites it by rename, which fails on a bind-mounted single file.
- **`package = null`**: the jail installs `claude`. **`settings.json` is immutable** (store symlink, `mutableSettings = false`); changes made from the UI do not persist — declare them in Nix.
- **Auto memory is disabled** with `settings.autoMemoryEnabled = false`. Existing memory files are preserved; explicit project/user instruction files still load.
- **Permissions**: `defaultMode = "auto"`. Bash rules come from the jailed `agent-shared/_bash.nix` (`"*"` → plain `Bash`). The translation is only lossless because every override in that set narrows toward ask/deny: Claude resolves by **deny > ask > allow**, so an override that *widens* would silently stop working. MCP rules use `mcp__plugin_hm_<server>__<tool>` — the HM module bundles all servers into a generated plugin named `hm`. Allow-rule globs need the literal `mcp__<server>__` prefix.
- **MCP**: context7, nixos, `host` (the `host-mcp.py` shim — `host_*` are in `ask`, which prompts even when an allow also matches), Notion, Linear, Datadog (`type = "http"`, OAuth via `/mcp`). Linear/Notion reads are allowed; writes fall through to a prompt. Datadog is fully allowed. They are global, not scoped to the subagents — subagent-only inline servers would not appear in `/mcp` for the OAuth login.
- **Agents**: `test-writer` (shared), `troubleshoot`, and `tickets` (Linear/Notion research plus exact mutation proposals in the parent-supplied shape). `tickets` does not impose another spec/ticket schema or write headlessly. Read-only agents use `disallowedTools: Write, Edit, NotebookEdit`.
- **Status line**: `claude-statusline` (`statusline.jq` + a shell wrapper adding the git branch, `*` when tracked files are dirty). Shows model + effort, active agent, dir + branch, context %, the 5h/7d plan limits (and `$` spend limit behind a gateway) with time to reset, and lines +/-. Percentages go green/yellow/red at 70/90%. Limits only appear after the first response in a session.
- **Prompt input**: `editorMode = "vim"`. Vim motions are not remappable; only `vimInsertModeRemaps` exists.
- **Commands**: shared `/commit` only. Configured review/PR workflows are skills, without forwarding aliases or a custom reviewer.
- **Skills**: the 26 shared development skills above, `git-conventions`, `datadog-queries`, plus `herdr` (from `herdr.nix`) and `jgrep` (from `work/jgrep.nix`) via `programs.claude-code.skills`, which is a no-op when the module is disabled.
- **Plugins**: none. Caveman/Ponytail were replaced by `agent-shared/style/` (see [Context budget](#context-budget)).
- **herdr**: `hooks."herdr-agent-state.sh"` is deployed from `${pkgs.herdr.src}` (version-matched) and registered as a `SessionStart` hook with the **exact** command string herdr's own installer writes, so `herdr integration install claude` is a no-op and `herdr integration status` is clean. Never run the installer: it would try to rewrite the immutable `settings.json`. Sidebar tokens come from our own `claude-activity.py` hooks (see [Agents sidebar](herdr.md#agents-sidebar)); `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` turns on the task tools it reads.

## rtk (shell-output compression)

`modules/programs/rtk.nix` (aspect `rtk`, in `user-base`) installs nixpkgs `rtk`: the full edition, with the BUSL `engine` feature compiled in. No `pipeline.toml` is written, so it runs `rtk:default`: the Bash rewrite plus per-command filters. PostToolUse compression, routing to other models, directives, `rtk-proxy` and telemetry all stay off.

- **Claude**: a `PreToolUse` hook on `Bash` runs `rtk hook claude`. It rewrites supported commands (`git status` to `rtk git status`) through `updatedInput`. rtk returns `allow` only when one of our allow rules matched, and Claude still applies its deny and ask rules over a hook `allow`.
- **omp**: `~/.omp/agent/extensions/rtk.ts` is upstream's shared Pi/OMP extension, copied from `pkgs.rtk.src`. It rewrites `event.input.command` in place.
- **Rule twins**: Claude checks permission rules against the *rewritten* command, and omp's order is unverified. So `agent-shared/_bash.nix` gives each pattern not starting with `*` an `rtk <pattern>` twin with the same action. Without the twins, `rtk nix run …` would slip past `nix run*` and land on the jailed `*` allow. rtk 1.0.1 has no nix or herdr rewrites; the twins guard against future ones.
- **Hermes** (macmini): the `rtk-rewrite` Python plugin, linked per profile by the Hermes bootstrap. See [Voice services](voice-services.md#hermes-agent).
- **Never run `rtk init`**: it would patch the immutable `settings.json` and the Nix-owned extension.
- **Stats**: `~/.local/share/rtk` (tracking DB) is bound read-write in the shared jail, so `rtk gain` persists. The home-manager activation creates the directory.

## Editing guidelines

- **Agent jail**: `agent-jail/_mk-jail.nix` is shared — a change there affects both harnesses. After touching `agent-shared/_bash.nix` or a harness's `_permissions.nix`, verify the rendered ruleset rather than the source.

## Context budget

Trimmed after [aihero's bloat article](https://www.aihero.dev/how-to-kill-the-bloat-in-claude-codes-system-prompt). Measure with `/context` in either harness (omp also has `/dump` for the raw request and `/tools`).

- **Style rules**: Caveman (default intensity) and Ponytail (`full`) are local adapted copies in `agent-shared/style/`, appended to both harnesses' global context through `shared.contextText`. No plugins, extensions, hooks, mode trackers, bands or statusline stamps. "stop caveman"/"stop ponytail"/"normal mode" are plain instructions in the text. The caveman-commit rules live in `git-conventions`; the caveman-review format and ponytail-review checklist live in `code-review`. Credits and licenses: `third-party/README.md`. Hermes keeps the upstream integrations through the `caveman`/`ponytail` flake inputs.
- **Claude Code**: `disableBundledSkills` and `disableWorkflows`. `permissions.deny` holds bare tool names (`unusedTools`), which drop the definitions from the context, and server-level `mcp__claude_ai_<Name>` rules for every unused claude.ai connector (`unusedConnectors`). Slack and Claude Docs stay. Plan mode, AskUserQuestion, Monitor, task tools and Artifact stay. Check `/skills` after changes: if `disableBundledSkills` hides the `artifact-*` skills, switch to per-skill `skillOverrides`.
- **omp**: `extensions = []`; no Google Calendar tool; `instructions = false` on context7, nixos, Notion and Datadog in `mcp.json`, because AGENTS.md already routes them. omp subagents share the parent's MCP manager, so MCP servers cannot be scoped to a single agent. Every MCP tool still costs one `xd://` catalog line.
- **Kept global by choice**: Slack, Notion, Linear and Datadog, including in non-work repos.

## Context ownership and operational safety

`agent-shared/context.md` owns cross-platform evidence, scope, cwd, and workflow routing. `agent-jail/jail-context.md` owns the Linux operational safety contract. Linux omp and the existing laptop Claude installation combine them; Darwin omp receives only shared context. Keep detailed infrastructure history here rather than duplicating always-loaded instructions.

Child processes, subagents, and MCP servers share the jail. Prefer ordinary sandbox tools when sufficient. Host approvals apply to each exact call, not the whole tool: explain outside access, use the narrowest tool, and batch only related work. “Always” does not authorize a whole host tool, and wildcard approvals must not broaden that boundary. Respect refusals; do not retry through a broader tool to circumvent one. Use `host_journal` for the journal, `host_mount` for files, `host_ssh_agent` before SSH work, and `host_exec` only when narrower tools cannot do the job. Outside the jail, `HOST_QUERY_PORT` is absent and ordinary host commands apply under existing approvals.

Changing directory does not reload the inherited environment; use `direnv exec <directory> <command>` when another environment is required. Signed commits use approved `host_exec`; never disable signing or rewrite Git configuration to bypass the missing signing socket. A host grant exposes real host files: deletion affects those files, not a private copy. Keep per-mount trash and recovery copies; do not clean them away. Nix daemon builds work inside the jail, while execution and deployment retain normal approval routes.

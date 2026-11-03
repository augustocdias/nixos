# Coding agents reference

[Herdr](herdr.md) owns terminal lifecycle and sidebar integration.

## Harnesses and shared pieces

- **omp** (oh-my-pi) is the personal harness: aspect `omp` in `user-base` (laptop and macmini), plus `omp-jail` in `user-linux`.
- **Claude Code** is the work harness: aspects `claude-code` and `claude-code-jail`, included only by the `work` aspect (laptop).

Shared material lives in `modules/programs/agent-shared/` and `modules/programs/agent-jail/`:

- `agent-shared/agent-shared.nix`: shared packages, included by both harness aspects. It installs terminal-browser from the same `llm-agents` input as Herdr.
- `agent-shared/_lib.nix`: prompt bodies are frontmatter-free, and each harness renders its own frontmatter through `withFrontmatter`, because the harnesses disagree on keys. `contextText` is `context.md` plus the style rules in `style/`.
- `agent-shared/_bash.nix`: the bash ruleset, translated by each harness's `_permissions.nix`. See [Approvals](#approvals) for why overrides may only narrow.
- `agent-jail/_mk-jail.nix`: the bubblewrap jail used by both harnesses. `agent-jail/jail-context.md` is loaded only inside the jail.
- `agent-jail/_host-query/` backs the `host_*` tools; `agent-jail/host-mcp.py` exposes them to both harnesses as a stdio MCP server.
- `agent-jail/_herdr-relay/` publishes restricted sidebar metadata to the launching Core terminal and proxies the Herdr App socket into the jail.

The `caveman` and `ponytail` flake inputs are declared in `omp.nix` and `claude-code.nix` but consumed only by Hermes (`modules/services/hermes-agent/`). The harnesses use the adapted copies in `agent-shared/style/`.

Both harnesses install the terminal-browser skill from `agent-shared/skills/terminal-browser/`. It launches browsers in Core terminals rather than using the browser's legacy Herdr TUI split adapter. The skill owns browser/tab selection, screenshots and cleanup while preserving each harness's sandbox and approval rules.

## Development skills

Both harnesses install every skill under `agent-shared/skills/` from one bundle (`agent-shared/_skills.nix`), which copies the shared `WORKFLOW.md` into each installed skill root so companion reads stay inside that root. Licenses and attribution live only in `third-party/` and are not installed.

Skills specific to this repo (`den-module`, `nvim-plugin`, `sops-secrets`) live in `.claude/skills/` and are not installed by Nix. Claude Code reads that folder as project skills, and omp reads it through its built-in `.claude/skills` provider.

- **Provenance**: the Matt Pocock skills are local curated copies, not a flake input. `third-party/mattpocock-skills/UPSTREAM.md` records the reviewed revision and the local adaptations. Updates are deliberate copy-and-review operations verified in both harnesses. `unslop` comes from pstack at the revision in `third-party/README.md`. `git-conventions` is local.
- **Routing and workspace contract**: `skills/WORKFLOW.md` owns invocation (including which skills are manual-only), `.dev-skills/` workspace resolution, delegation, and artifact handling. `agent-shared/context.md` carries the always-loaded routing summary. Edit those files, not this doc, when the contract changes.
- **Boundaries** that every skill workflow keeps:
  - `git-conventions` owns the upfront agreement for branch, worktree, commit, push, and PR ownership. Read-only work needs none.
  - Existing approvals stay mandatory. Routine delegation never authorizes published rewrites, merging PRs, destructive cleanup, or repository-setting changes.
  - The parent owns credentials, signed commits and pushes (through Linux `host_exec`), refs, tracker writes, and shared progress. Required `host_ssh_agent` approval comes before any subagent starts.
  - Delegates receive the parent's absolute `.dev-skills/` workspace, even outside their own Git root. One writer owns each checkout.
  - `.dev-skills/` artifacts never enter implementation commits or pushes. Local exclusion is not encryption or backup.
  - Generated wizards run on the host, by the human.
- **omp task isolation is off** (`task.isolation.enabled = false`): its automatic snapshots are not permission-controlled Git worktrees, and `implement-spec` assigns approved worktrees itself.

## Agent sandbox (Linux only)

On Linux, `omp` and `claude` are the jail: `_mk-jail.nix` wraps each package with bubblewrap through the `jail-nix` combinator library and installs it under the original binary name. Darwin has no sandbox and relies on the bash allowlist alone. `agent-jail/jail-context.md` is the agent-facing contract for writable areas, host access, SSH, signing, and deletion. Keep it in sync when the jail changes.

Gotchas behind the jail's design:

- **Writes outside the binds vanish.** `/`, `/etc`, `/tmp`, and `$HOME` are per-session tmpfs, so a successful write there proves nothing. Per-harness state (grants, logs) lives in `~/.local/share/<name>-jail/`.
- **Linked worktrees need the git-common-dir bind.** The launcher binds `git rev-parse --git-common-dir` when it differs from the git dir; without it git fails outright.
- **No setuid.** bwrap sets `PR_SET_NO_NEW_PRIVS` unconditionally, so in-jail `sudo nixos-rebuild` cannot activate the host. Approved `host_exec` and authorized remote deployment still work.
- **`NIX_REMOTE=daemon` is mandatory.** The uid map makes the store look user-owned and tricks nix into single-user mode. Because `trusted-users = root`, a client cannot disable the build sandbox, which is why `nix build` is safe to allow inside.
- **No curated toolbelt.** `/nix/store` is bound read-only and PATH comes from `/run/current-system/sw` and `/etc/profiles/per-user/<user>`. Curating tools would not be a boundary, since every store binary is reachable by absolute path.
- **The host environment is inherited.** jail-nix's `base` ends with `--clearenv`, so the jail uses `reset` and rebuilds the pieces without it; that is how sops-derived keys, `HERDR_*`, and direnv exports arrive. Consequence: `add-path` seeds from an empty PATH, so use `set-env "PATH" "…:$PATH"`.
- **`GPG_TTY` is removed twice**: unset in the first runtime block (before `pre` and host-query start) and `--unsetenv` in the final block (after caller overlays). gpg-agent keeps its own terminal and display state, so a missing `GPG_TTY` does not prove GUI pinentry. Do not flush caches or restart the agent just to force a prompt.
- **No gpg-agent socket.** The agent is a signing and decryption oracle: exposing it would let the jail sign as the user and decrypt every sops secret. With `signByDefault = true` in the read-only git config, `git commit` fails for lack of a signer. That failure is the approval gate; signed commits go through `host_exec`.
- **SSH comes from a relay, on approval.** `SSH_AUTH_SOCK` is unset at launch. `host_ssh_agent` makes host-query listen on `<grant_root>/ssh-agent.sock` and pipe each connection to the host's `S.gpg-agent.ssh` until host-query exits. It is a relay rather than `host_mount` because a socket seen through bindfs/FUSE cannot be `connect()`ed. `~/.ssh/known_hosts` is read-only and private-key directories are not mounted. The SSH capability is not authorization: pushes and deletions keep their normal approvals, and host verification is never weakened.
- **No D-Bus.** The session bus reaches `systemd --user`, which can start units outside the jail. OMP's direct desktop notifications are therefore unavailable inside the jail.
- **`rm` and `rmdir` are rmtrash, and trash is per mount.** Each writable path is its own bind mount, so deletions land in that mount's `.Trash-1000` (a rename into the home trash would fail with `EXDEV`). That is why `programs.git.ignores` contains `.Trash-*/`. `~/.local/share/Trash` is deliberately not bound.

### Core sidebar reporting

For App terminals, the launcher captures `HC_TERMINAL_ID` and `HC_TERMINAL_SOCKET` before entering the jail. A per-launch bridge in `_herdr-relay/server.py` accepts only `activity.report` snapshots. It constructs Core label requests itself, with a fixed terminal and display namespace. Agents cannot select a different target or invoke other Core methods through it.

The final mounts replace the inherited host Core endpoint and its canonical path with the reporting socket. `HERDR_ACTIVITY_SOCKET` points to that restricted endpoint inside the jail. The launcher removes legacy Herdr identity variables. A missing host Core endpoint or an existing reporter lock aborts launch rather than exposing a fallback socket. Core reporting logs live beside the host-query logs.

The bridge clears its label on normal exit and stops when its launcher exits. Renderer leases cover crashes where cleanup cannot run. This is metadata transport, not general `hc` access; the user's App, human terminals and Core lifetime remain unchanged.

### Session-owned Core

Each Linux jail gets its own Core endpoint through `HC_SOCKET`, separate from the sidebar bridge. The in-jail `hc` wrapper selects private runtime, config and state directories and removes the root reporter's identity before starting Core. A custom runtime directory keeps Core and its holders off host systemd. The root harness's inherited `HC_TERMINAL_ID` and `HC_TERMINAL_SOCKET` are removed so host terminal IDs cannot address sandbox terminals accidentally.

Core starts on demand. Its services use the existing project mounts and shared network, so an agent can start a dev stack and run E2E checks against localhost without another permission prompt. The PID namespace ends Core and all its programs when the jail closes, including programs marked `--outlive-parent`. Separate agent sessions do not share terminals. This does not add network isolation or change the accepted host-helper approval model.

`HERDR_SANDBOX_SOCKET` names the host-visible socket for an approved viewer. `herdr-core-view SOCKET TERMINAL` runs `hc attach` in a second, minimal bubblewrap jail with only that socket inode and the Nix store mounted. Binding the inode prevents attach's autostart path from creating a host Core if the owning jail disappears. The App proxy below opens this viewer for every program an agent starts through the App; no machine connection or reverse-callback route is added.

The launcher refuses working directories or shared Git directories that would expose the host App home or runtime directories. The normal Home Manager App files remain outside the agent jail. Both harnesses install the repo-owned `herdr-app` and `herdr-core` skill directories from `modules/programs/herdr/skills/`, including the App skill's mod-development companion.

Linux `hc` and `herdr-app` use the jailed default allow policy; the App proxy below is the boundary for `herdr-app`. Darwin keeps explicit `herdr*` prompts.

### App proxy

The raw App socket is a host code-execution route: `terminal.open`, `tab.new`, `pane.split` and `space.new` start their `argv` in the host Core, and paste, mods and layout clicks reach host programs too. The launcher therefore starts `_herdr-relay/app_proxy.py` outside the jail and binds its socket over `$app_home/herdr-app.sock`, so the stock `herdr-app` client works unchanged inside the jail.

The proxy speaks the App's one-JSON-line protocol and sorts each request:

- Program-starting commands run their `argv` (plus `task`) in the jail's Core through `terminal.run`, then forward the command with `argv` replaced by `herdr-core-view <core socket> <id>`. The reply gains `sandbox_terminal`. If the App refuses the view, the proxy kills the jail terminal. `machine`, `mod` and `props` are refused.
- View commands (select, focus, zoom, rename, move, layout visibility, `ls`, `status`) pass through unchanged.
- Close, kill, keep and park need an explicit target that the proxy created this session. `tab.new` replies with an existing space, so only `space.new` makes a space closable.
- `shot` renders into a proxy-private directory, then copies the PNG under the workspace by walking `O_NOFOLLOW` directory descriptors, because the jail can swap any workspace path for a symlink.
- Everything else, including mod commands and `app.*` settings, update and quit commands, is refused.

The jail owns the path of its Core socket and could link it to the host Core. Before each Core call the proxy reads `SO_PEERCRED` and refuses a peer in its own (host) PID namespace. Another jail's Core would still pass that check; the result stays sandboxed.

`tab.new` and `space.new` wrap the viewer in the host shell's `-ic` form, so the pane falls back to a host shell after the jail terminal ends. The agent cannot type into it: paste is refused, and `task` never reaches the App. Jail terminals outlive their viewer panes; the agent ends them with `hc kill`. The proxy reaches the jail Core only once Core is running, so its error asks the agent to run `hc ls` first.

`python3 -m unittest test_app_proxy` in `_herdr-relay/` covers refusals, rewriting, ownership, the PID-namespace check and screenshot containment; the package check phase runs it. Proxy logs live in `$jail_state/log/app-proxy-<pid>.log`.

### `host_*` tools

`host_exec`, `host_mount`, `host_journal`, and `host_ssh_agent` are the jail's only route to the host. host-query serves them on a Unix socket bound only into its own jail (`/tmp/host-query.sock`), and both harnesses prompt on every call. `host_exec` runs one command unsandboxed; `host_mount` bindfs-grants a host directory at `~/granted/<name>`; `host_journal` reads the journal with a fixed argv; `host_ssh_agent` relays the SSH agent. Outside the jail `HOST_QUERY_SOCKET` is unset and all four short-circuit.

`host_journal` exists because the user namespace cannot map supplementary groups, so the `wheel` membership the journal ACL needs is gone. In-jail `journalctl` prints "No journal files were found" and exits 0, a silent-success trap.

If a `host_*` tool misbehaves, read `~/.local/share/<name>-jail/log/host-query.log` (bound read-only into the jail).

## oh-my-pi (omp)

`modules/programs/omp/`. omp has no sandbox of its own: its approval system is policy, not containment, so on Linux it runs in the shared jail.

OMP and terminal-browser use the same `llm-agents` flake input as Herdr, without overriding its nixpkgs, so their upstream store paths remain eligible for `cache.numtide.com`. Updating that input updates all its consumers.

The Nix overlay disables OMP's built-in browser prelude in favor of the shared terminal-browser CLI workflow.

- **Not the upstream HM module.** Its `package` is not nullable (the jail installs `omp`) and it writes only `config.yml`.
- **Settings go through `PI_CONFIG_FILES`**, set by `wrapProgram`. omp rewrites `~/.omp/agent/config.yml` from `/settings` and migrations, so that file cannot be a store symlink. The overlay ranks above global and project config and is never written back. Overlays replace arrays, so the pinned empty `extensions` stops a project from adding packages. Keys the overlay omits stay omp's, except the models below.
- **Everything else is `home.file`** under `~/.omp/agent/`. Read-only symlinks work because only `/mcp add|enable|disable` rewrites them, and that is not used. Extensions load from store symlinks: the loader resolves realpath, Bun imports `.ts` directly, and `@oh-my-pi/*` imports resolve to bundled copies, so no `node_modules` is needed.
- **All runtime state is under `~/.omp`** (credentials and MCP OAuth tokens in `agent.db`, sessions, worktrees), hence the single read-write bind.
- **Provider**: OpenAI Codex, logged in at runtime with `/login openai-codex`. Do not use `/login anthropic`: it works by impersonating Claude Code's client.
- **Shared prompts**: omp has no `` !`cmd` `` injection, so `omp.nix` strips the markers from shared commands and tells the model to run them.
- **Models**: roles and per-agent overrides are in `omp.nix`; overrides win over agent frontmatter. They stay out of the overlay so a repo's `.omp/config.yml` can replace them: the `omp-models` activation merges them into `config.yml` with `yq`, which puts them in the global layer, below project config. A project file that sets only some roles leaves the rest on Codex. This repo's `.omp/config.yml` points every role at Ollama Cloud through the built-in `ollama-cloud` provider, which reads `OLLAMA_CLOUD_API_KEY`. Cloud ids carry their tag before the thinking level (`deepseek-v4-pro:0813:high`); omp splits the level at the last colon. Ids come from the bundled catalog, which Codex replaces with its live `/models` list after login, so a missing id shows up as a role fallback in `/models`. Start on the slow role with `omp --model @slow`.
- **`bash.gitGuard = false`** lets skill ownership agreements permit branch switching. Shared bash rules and host, SSH, MCP and Nix approvals still apply. `herdr-app` asks on both platforms; other explicit Herdr prompts remain on Darwin.
- **Keybindings** in `omp.nix` move OMP actions off chords captured by Herdr App and OmniWM.

### Approvals

- `_bash.nix` overrides must only narrow toward ask or deny. omp resolves `bash.patterns` by first match, so `_permissions.nix` emits deny, then prompt, then allow. Claude resolves deny > ask > allow. Either way, a widening override would silently stop working.
- Jailed: `approvalMode = yolo`, because the jail is the boundary. Darwin: `approvalMode = write` plus the unjailed allowlist.
- The `host_*` tools are `tools.approval: prompt`. Explicit prompts hold even in yolo and never offer "approve for session".
- Subagents always run yolo, but deny and prompt still apply (a prompt rejects).
- `eval` is not gated in the jail: it reaches no more than bash already can.
- **Work MCPs go through `extensions/gate.ts`.** Approval keys are exact names without wildcards, and the work servers add tools upstream, so an exact list would silently allow new writes. `gate.ts` passes read verbs and confirms everything else. Without a UI it blocks, so an omp subagent can never write to Linear, Notion, or Datadog. This is stricter than Claude, which fully allows Datadog.

### Work MCPs

`modules/services/work/work.nix` (laptop only) adds Notion, Linear, and Datadog to omp through the `omp.mcpServers` option, plus the `troubleshoot` and `tickets` agents (limited to `omp.readOnlyTools`) and the `datadog-queries` skill. OAuth runs with `/mcp reauth <name>`; the callback listens on `:3000` inside the jail, which shares the host network. The omp `tickets` agent gets a preamble telling it to return each mutation as a proposal, because `gate.ts` blocks its writes and the parent session must perform them.

## Claude Code

`modules/programs/claude-code/`, configured through home-manager's `programs.claude-code`.

- **`CLAUDE_CONFIG_DIR=$HOME/.claude`** is set inside the jail so `.claude.json` lives inside the bound directory. Claude rewrites that file by rename, which fails on a bind-mounted single file.
- **`settings.json` is immutable** (store symlink). UI changes do not persist; declare them in Nix. `package = null` because the jail installs `claude`.
- **Permissions**: bash rules come from the jailed `_bash.nix` (`"*"` becomes plain `Bash`); see [Approvals](#approvals) for the narrowing rule. The HM module bundles all MCP servers into a generated plugin named `hm`, so rules use `mcp__plugin_hm_<server>__<tool>`, and allow-rule globs need that literal prefix. The `host_*` tools are in `ask`, which prompts even when an allow rule also matches.
- **MCP servers are global**, not scoped to the work subagents, because subagent-only inline servers would not appear in `/mcp` for the OAuth login.
- **Status line**: plan limits appear only after the first response in a session.
- **Prompt input**: vim motions are not remappable; only `vimInsertModeRemaps` exists.
- **Skills** also come from other modules through `programs.claude-code.skills`: `herdr-app` and `herdr-core` from `herdr.nix`, and `jgrep` from `work/jgrep.nix`.
- **Herdr sidebar**: `herdr.nix` registers `claude-activity.py` for display metadata. Native OSC reports supply lifecycle status independently; see [App sidebar](herdr.md#app-sidebar).

## rtk (shell-output compression)

`modules/programs/rtk.nix` (aspect `rtk`, in `user-base`) installs nixpkgs `rtk`, the full edition with the BUSL `engine` feature. No `pipeline.toml` is written, so it runs `rtk:default`: the bash rewrite plus per-command filters.

- **Claude**: a `PreToolUse` hook on `Bash` runs `rtk hook claude`, which rewrites supported commands (`git status` to `rtk git status`) through `updatedInput`. rtk returns `allow` only when one of our allow rules matched, and Claude still applies its deny and ask rules over a hook `allow`.
- **omp**: `~/.omp/agent/extensions/rtk.ts` is upstream's extension from `pkgs.rtk.src`, version-matched to the binary. It rewrites the command in place.
- **Rule twins**: Claude checks permission rules against the rewritten command, and omp's order is unverified. So `_bash.nix` gives each pattern not starting with `*` an `rtk <pattern>` twin with the same action. Without twins, `rtk nix run …` would slip past `nix run*` and land on the jailed `*` allow.
- **Hermes** (macmini) uses the `rtk-rewrite` plugin; see [Voice services](voice-services.md#hermes-agent).
- **Never run `rtk init`**: it would patch the immutable `settings.json` and the Nix-owned extension.
- **Stats**: `~/.local/share/rtk` is bound read-write in the jail, so `rtk gain` persists. The home-manager activation creates the directory, because the jail skips a missing bind source.

## Context budget

Measure with `/context` in either harness; omp also has `/dump` for the raw request and `/tools`.

- **Style rules**: `agent-shared/style/` holds adapted Caveman and Ponytail rules, appended to both harnesses' context. They are plain text, so "stop caveman" and similar are ordinary instructions. Related rules live in skills: commit style in `git-conventions`, review format in `code-review`, persisted prose in `unslop`. Credits are in `third-party/README.md`.
- **Claude Code**: bare tool names in `permissions.deny` (`unusedTools`) drop those definitions from the context, and `mcp__claude_ai_<Name>` rules (`unusedConnectors`) drop unused claude.ai connectors. `disableBundledSkills` and `disableWorkflows` are on. Check `/skills` after changes: if `disableBundledSkills` hides the `artifact-*` skills, switch to per-skill `skillOverrides`.
- **omp**: `instructions = false` drops long MCP server instructions where AGENTS.md already routes the server. omp subagents share the parent's MCP manager, so a server cannot be scoped to one agent. Every MCP tool still costs one `xd://` catalog line.
- **Work MCPs stay global by choice**, including in non-work repos.

## Editing and verification

- `_mk-jail.nix`, `_bash.nix`, `jail-context.md`, and `host-mcp.py` are shared: a change affects both harnesses.
- After changing `_bash.nix` or a harness `_permissions.nix`, inspect the rendered rules (Claude's `settings.json`, omp's `PI_CONFIG_FILES` overlay), not only the source.
- Keep `jail-context.md` (agent-facing sandbox contract) and `agent-shared/context.md` (cross-platform routing) as the always-loaded owners. Put detail here, not there.

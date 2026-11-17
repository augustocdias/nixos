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
- `agent-jail/_herdr-relay/` publishes restricted sidebar metadata to the launching Core terminal.

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
  - Every commit is signed when it is created: with the agent key in a session holding the signing grant, otherwise through `host_exec`. A pre-push `git verify-commit` over every outgoing commit gates each push.
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
- **The launcher's environment is inherited.** jail-nix's `base` ends with `--clearenv`, so the jail uses `reset` and rebuilds the pieces without it. Core-launched commands do not necessarily have the credentials loaded by an interactive shell. `_mk-jail.nix` fills missing or empty `GH_TOKEN`, `TYPESAFE_API_KEY` and `OLLAMA_CLOUD_API_KEY` from their sops files before entering the jail, preserving nonempty inherited values. An unreadable or empty required secret stops launch with a variable-name error. Only paths enter the Nix store; values are exported at runtime and the secret directory is not mounted. The shared loader covers omp, Claude and Hermes. Other environment values still depend on the launcher. Consequence: `add-path` seeds from an empty PATH, so use `set-env "PATH" "…:$PATH"`.
- **`GPG_TTY` is removed twice**: unset in the first runtime block (before `pre` and host-query start) and `--unsetenv` in the final block (after caller overlays). gpg-agent keeps its own terminal and display state, so a missing `GPG_TTY` does not prove GUI pinentry. Do not flush caches or restart the agent just to force a prompt.
- **No gpg-agent socket.** The agent is a signing and decryption oracle: exposing it would let the jail sign as the user and decrypt every sops secret. With `signByDefault = true` in the read-only git config, ordinary `git commit` fails for lack of a signer. Signed commits go through `host_exec`, or through the agent key when the session holds the [signing grant](#signing-and-push-grant).
- **SSH comes from a relay, on approval.** `SSH_AUTH_SOCK` is unset at launch. `host_ssh_agent` makes host-query listen on `<grant_root>/ssh-agent.sock` and pipe each connection to the host's `S.gpg-agent.ssh` until host-query exits. It is a relay rather than `host_mount` because a socket seen through bindfs/FUSE cannot be `connect()`ed. `~/.ssh/known_hosts` is read-only and private-key directories are not mounted. The SSH capability is not authorization: pushes and deletions keep their normal approvals, and host verification is never weakened.
- **No D-Bus.** The session bus reaches `systemd --user`, which can start units outside the jail. OMP's direct desktop notifications are therefore unavailable inside the jail.
- **Jails refuse to nest.** Each jail sets `AGENT_JAIL`, and a launcher that sees it exits with a pointer to `hc run`. A nested launch half-worked before: `claude` failed on its read-only state directory, and `omp` started without `~/.omp`, so it had no login or config.
- **`rm` and `rmdir` are rmtrash, and trash is per mount.** Each writable path is its own bind mount, so deletions land in that mount's `.Trash-1000` (a rename into the home trash would fail with `EXDEV`). That is why `programs.git.ignores` contains `.Trash-*/`. `~/.local/share/Trash` is deliberately not bound.
- **Host containers.** `_mk-jail.nix` exposes the rootless Podman socket through `DOCKER_HOST` for Docker API clients and `CONTAINER_HOST` for the Podman-backed `docker` CLI. The Podman aspect already enables the user socket through `sockets.target`. The launcher mounts its directory rather than its inode so socket replacement remains visible. A read-only socket mount does not limit API authority; agents can manage host containers and container bind mounts resolve on the host. Jail-private `/tmp` files are not usable as host container bind sources. See [Podman's API service](https://github.com/podman-container-tools/podman/blob/main/docs/source/markdown/podman-system-service.1.md).
- **GitHub CLI and pnpm storage.** The shared launcher creates and binds each tool's data, cache and state directories read-write, including pnpm's store and global installs. It honors the XDG roots and `PNPM_HOME`; GitHub configuration remains read-only and honors `GH_CONFIG_DIR`. See [GitHub CLI path resolution](https://github.com/cli/go-gh/blob/trunk/pkg/config/config.go) and [pnpm store settings](https://pnpm.io/settings#storedir). Project-specific store paths outside these mounts still need a workspace bind or a grant. Shared caches are writable host state, not disposable sandbox copies.

After changing these mounts, rebuild and start fresh harness sessions. Existing jails keep their old mounts and environment. Verify with `gh extension list`, `pnpm store path` inside the project's development environment, and `docker info`. If the container API cannot connect, check `systemctl --user status podman.socket` on the host. A focused mount smoke test should also replace a temporary Unix socket while the jail remains open and verify persistent writes under both default and overridden storage roots.

### Core sidebar reporting

For App terminals, the launcher starts a per-launch bridge in `_herdr-relay/server.py` accepts only `activity.report` snapshots. It constructs Core label requests itself, with a fixed terminal and display namespace. Agents cannot select a different target or invoke other Core methods through it.

`HERDR_ACTIVITY_SOCKET` points to that endpoint inside the jail. The collectors use it rather than the Core socket, because the bridge owns the per-terminal lock, the session epochs and label cleanup. The launcher removes legacy Herdr identity variables. A missing host Core endpoint or an existing reporter lock aborts launch. Core reporting logs live beside the host-query logs.

The bridge clears its label on normal exit and stops when its launcher exits. Renderer leases cover crashes where cleanup cannot run. This is metadata transport only.

### Signing and push grant

Autonomous runs need children that commit and push, and children have no host access. The grant gives a session a separate agent SSH key for both, without exposing the user's GPG key.

- **The user grants it at launch** with `AGENT_JAIL_SIGNING=1 claude` (or `omp`). The launcher starts an ssh-agent on the host, loads the sops secret `agent_ssh_key`, and binds only the agent socket into the jail as `/tmp/agent-ssh.sock`. The jail can use the key, never read it.
- **Git is configured through the environment** (`GIT_CONFIG_COUNT`), which has command-line precedence over the read-only Home Manager config: `gpg.format=ssh`, `user.signingkey=key::<public key>` (ssh-keygen then signs through the agent), and `gpg.ssh.allowedSignersFile` for `git verify-commit`. SSH pushes find the key through `SSH_AUTH_SOCK`.
- **A granted session passes it on by variable.** `hc run -- env AGENT_JAIL_SIGNING=1 claude …` grants the child. Nothing enforces that only granted sessions do this, since any jail can reach Core; `git-conventions` limits it to granted sessions whose worker ticket asks for signing or pushing.
- **Setup.** `agent-jail/agent-ssh-key.pub` holds the public key, and GitHub lists it as both an authentication key and a signing key. Without that file or the secret, a grant prints a warning and the session runs ungranted. Agent logs live in `$jail_state/log/agent-key-<pid>.log`.

The key authenticates as the user's GitHub account, so a granted session can push to any repository that account can push to. Branch protection is what keeps agents off protected branches.

### `host_*` tools

`host_exec`, `host_mount`, `host_journal`, and `host_ssh_agent` provide approved host access from the jail. Herdr separately starts programs on the host through Core and App. host-query serves the `host_*` tools on a Unix socket bound only into its own jail (`/tmp/host-query.sock`), and both harnesses prompt on every call. `host_exec` runs one command unsandboxed; `host_mount` bindfs-grants a host directory at `~/granted/<name>`; `host_journal` reads the journal with a fixed argv; `host_ssh_agent` relays the SSH agent. Outside the jail `HOST_QUERY_SOCKET` is unset and all four short-circuit.

`host_journal` exists because the user namespace cannot map supplementary groups, so the `wheel` membership the journal ACL needs is gone. In-jail `journalctl` prints "No journal files were found" and exits 0, a silent-success trap.

The shared `agent-jail/jail-context.md` requires sandbox bash for ordinary CLI work, including GitHub queries and `gh auth status`. Authentication alone does not justify `host_exec`; escalation needs a concrete unavailable capability, supported by an error or a documented jail boundary. The coordinator's blocker instructions check for this wrong-tool case without authorizing it to answer or bypass an existing approval prompt.

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

## Work Hermes (laptop and macmini)

The `hermes-work` aspect includes `_work.nix` on both hosts. Its `hermes` wrapper runs Hermes directly. Linux uses a user gateway service and the official bubblewrap terminal backend. macmini uses local execution and the existing household system LaunchDaemon; no second gateway service is installed. The omp and Claude Code jails are unchanged. See [Voice services](voice-services.md#hermes-agent) for macmini's household profiles.

### Roles and task flow

`_models.nix` owns primary model/provider records by host and profile, including the default gateway and macmini's household profiles. `_fallbacks.nix` owns each profile's ordered fallback chain in Hermes's `provider`/`model` format; an empty list disables fallback. Linux work profiles cross between Codex and Claude subscriptions. macmini stays on loopback Ollama, changing models rather than providers. Utility models follow the host's default; decomposition follows its coordinator. Advanced delegation uses named profile routes, not model routes. Profiles do their own work with native tools; the reviewer can delegate an independent check.

Cards carry the `Repo`, `Tracker` and `Git` rows served by `board_template`. Creation requires an existing checkout under `~/dev` or the configured extra repositories. The board MCP and native creation hook set `workspace_kind=dir` and the explicit checkout path. The dispatcher supplies that directory to the terminal backend. Dispatch concurrency is one because cards can share a checkout; raising it requires separate workspaces for concurrent writers. Existing cards with scratch workspaces need replacement cards with explicit checkout paths before direct execution; their history and files are not deleted.

Roles create assigned, non-triage work. Only an interactive coordinator conversation may explicitly request triage. Assistant-created cards remain blocked until a human authorizes them. Dependencies select `todo` or `ready`; `parents` are dependency edges, not a hierarchy. Decomposed children inherit the original card's directory and missing run settings.

The programmer verifies changes and requests review with an exact range. `skills/sdlc-review/SKILL.md` governs independent review, authorized publication and exact-head CI. Findings return to the programmer on the same branch and PR. Board completion does not imply merging or external tracker closure. Roles use native card comments, blocking and completion tools. Shared formatting requires abbreviated PR references in comments and handoffs.

The coordinator retains blocker checks, guidance, unblocking and archiving through `hermes-workflow`. The watcher creates one check card per blocked event, except assistant mail cards; its decision remains on the blocked card when the completed check card is deleted. Plugin policy and watcher state live in `~/.hermes/hermes-workflow.json`, protected by a file lock.

### Git ownership

Each category—branches, worktrees, commits, pushes and PRs—is `agent` or `human`. Missing values and legacy `ask` values mean `human`. Background workers do not open permission dialogs: human-owned work produces a handoff.

The `git` tool accepts a task ID and an argument array, without an executable. It requires the current dispatcher-owned task, refuses delegated children and unrelated tasks, checks the checkout against the card, and snapshots its policy on first use. A subsequent metadata change fails closed until the user runs `hermes git-policy <task>` outside an agent terminal. Agents must not broaden grants when creating follow-up work.

`plugin/git_proxy.py` limits Git commands and options, disables hooks and external diff drivers, rejects executable repository configuration, and uses a fresh SSH agent containing only the dedicated agent key. It does not use the user's SSH agent or YubiKey. Commits are SSH-signed; pushes verify every newly introduced commit against the configured agent key or human GPG fingerprint. Pushes target an explicit branch and cannot force-update or delete refs. Fetches accept named GitHub remotes, not arbitrary URLs or refspecs.

PR ownership is a workflow rule, not a Git protocol operation. Only the reviewer receives the managed GitHub token for native publication and CI inspection. That token also permits direct GitHub API operations: the Git proxy does not constrain those APIs.

### Sandbox and plugins

- **Linux bubblewrap:** the network profile, default-deny home visibility, explicit secret hides and fail-closed backend startup. The task workspace and sandbox scratch space are writable. No Docker/Podman socket or host MCP is supplied.
- **macmini local execution:** terminal and file tools have the user's filesystem access; they are not sandboxed. Only advanced delegation and Home Assistant from the official plugin collection are installed.
- **Command policy:** terminal approval dialogs are off for unattended work. Both hosts unconditionally deny `nixos-rebuild`, `darwin-rebuild` and ordinary terminal Git commands. Other Nix development remains available.
- **Boundary:** Hermes, model providers, browser tools, MCPs and plugin tools run outside Linux's terminal sandbox. Network access is not filtered. Command-string denies and the Git proxy are workflow controls, not confinement against arbitrary hostile code: code can invoke Git indirectly, and writable repository configuration can race validation. Do not treat them as an adversarial authorization boundary.
- **Linux Claude subscription:** uses the packaged, unwrapped Claude CLI and the user's existing `~/.claude` login, with extra usage stopped. Bootstrap makes a private runtime copy of the pinned provider before linking it: Hermes's provider staging cannot copy read-only Nix-store directory modes. Other plugins remain store-linked. Update pins through Nix, not the plugin installer.
- **Advanced delegation:** configured profile routes on default, coordinator and reviewer, on both hosts. Delegated children cannot borrow a parent task's Git grant.
- **Linux Hermes security:** enabled for the reviewer, with the Nix-provided OSV scanner. The tool hook permits static scans only; reproductions belong in the sandboxed terminal. Advisory lookups may disclose dependency names and versions.
- **Linux REA:** enabled for engineering profiles, with a pinned npm MCP server and an explicit static-analysis tool allowlist. Process execution and debugger tools are not exposed. Native decompilation engines remain optional and are not provisioned. The server downloads on first use and reads files outside the terminal sandbox.
- **macmini Home Assistant:** tools are enabled for the coordinator and household profiles, not engineering workers. Authentication and service-control scope are described in [Voice services](voice-services.md#home-assistant).
- **Office 3D:** both hosts link the pinned [desktop plugin](https://github.com/oslook/hermes-desktop-plugin-office-3d). Home Manager also links its frontend file at `.hermes/desktop-plugins/office-3d/plugin.js`, leaving the parent directory writable for Desktop's package marker. Relying on Desktop's automatic copy from the Nix store fails because it preserves read-only directory permissions. The plugin is enabled in the root gateway and every managed profile so the selected Desktop backend can mount its API.
- **Office catalog identity:** `_bootstrap_work.py` registers the Nix-pinned source in each managed profile's `plugins/.install-metadata.json` through Hermes's locked installer helper. Desktop matches this catalog identity, not the package name. Registration runs after profile creation because adoption accepts only Home Manager plugin links. An in-tree `.hermes-catalog.json` alone is not trusted installer metadata.
- **Desktop capabilities:** `_work.nix` owns the default profile's `platform_toolsets.cli` and matching `agent.disabled_toolsets`. The Tools tab reads both; installing a plugin alone does not enable its toolset. Specialist and household profiles retain their separate allowlists.
- **Browser automation:** browser-enabled work profiles use a Nix-pinned executable: nixpkgs Chromium on Linux and Playwright's Chromium distribution on Darwin. Explicit gateway placement avoids the terminal-only bubblewrap backend's unsupported browser placement. Browsers run outside that sandbox with disposable profiles, without consent to reuse the user's browser logins.
- **Web search:** web-enabled work profiles select Exa's anonymous free tier. It needs no API key or additional Python packages, but is rate-limited.
- **A2A:** the default profile enables the toolset, without provisioning peers or opening an inbound listener. Hermes exposes the client tools only after peers or an inbound endpoint are configured.
- **Office frontend consent:** unified-package frontends start disabled independently of their backend toolsets. Search for `office-3d` in Desktop's Capabilities → Plugins and turn its switch on once. If the catalog offers Install, check the selected profile's installer record and gateway bootstrap rather than installing another copy. The decision lives in that frontend's local storage, not `ui-preferences.json`; Hermes deliberately excludes plugin grants from shared preferences. Nix manages installation and backend enablement, not this frontend consent.

### Bootstrap and runtime setup

`_bootstrap_work.py` serializes startup and merges Nix-owned settings into writable profile configurations, preserving unrelated runtime configuration. Model records are replaced rather than merged, so changing providers cannot retain an old endpoint or API key. Both bootstraps remove the legacy `fallback_model` key when applying managed fallback chains, preventing obsolete routes from being appended. Bootstrap fails on malformed YAML or unmanaged profile directories; it can adopt directories containing only Home Manager's plugin links. The root gateway explicitly runs `hermes -p default gateway run` with profile multiplexing; unrouted chat uses the interactive default profile's tool allowlist. On macmini, the household bootstrap runs first; the work bootstrap preserves its root API-listener `.env`.

SOULs combine the role file, shared role rules where applicable, host execution policy, shared evidence/development instructions and formatting. Shared development skills remain available; QA uses native browser tools rather than host Herdr launches.

Runtime setup includes authentication for the selected providers, chat channels and profile routes, coordinator MCP OAuth logins, and assistant Google login. Linux's default models need Codex authentication and a Claude CLI subscription login; macmini's defaults use the existing Ollama service. Linear, Notion and Datadog keep full MCP trust. The assistant has no terminal, delegation or Git tools; `google-login` grants only Gmail and Calendar read access.

Interactive CLI lifecycle still reports to Herdr through OSC 7501. Home Manager installs Desktop on both hosts. After plugin changes, restart the selected Desktop backend and reload the app; installing frontend files alone does not enable a plugin's backend API.

`_desktop-settings.nix` owns Desktop appearance preferences. Home Manager activation applies them with Hermes's native, locked preference writer to `~/.hermes/ui-preferences.json`. The file stays writable; unrelated preferences are preserved. Activation reapplies the global appearance and clears per-profile appearance overrides so every profile inherits it. Do not replace this file with a read-only Nix-store link.

Bot avatar PNGs live in `modules/services/hermes-agent/assets/`. `_work.nix` links each managed avatar into its profile's `assets/avatar.png`, with the default profile under `~/.hermes/assets/`. The librarian image is reserved for a future profile. Change avatars in Nix rather than Desktop; an editor replacement can remove the managed symlink.

After activation, restart Linux's gateway manually (`X-RestartIfChanged=false`). macmini retains `system/org.nixos.hermes-agent`; do not install a second user gateway. Reconnect board MCP clients so tool schemas refresh. Do not switch a running workload mid-task. Updating configuration does not stop external workers already running from earlier sessions.

For `Unknown provider` errors, check the actual running executable as well as `command -v hermes`. An older session keeps its old package and sandbox after activation. Relaunch through the current Home Manager wrapper, which selects the unwrapped Claude CLI; the old full-process Hermes jail does not expose the Claude login. Provider registration runs outside the current terminal-only bubblewrap backend.

### Verification

- Inspect each rendered profile and `hermes -p <profile> tools list --platform cli`. Engineering roles need terminal/file/Git tools; the assistant must not have them.
- In isolated profiles, exercise both terminal backends and the Git/rebuild denies. On Linux also check workspace writes, hidden SSH/Hermes state, and outside-workspace write denial.
- Exercise Office's frontend reconciliation through Desktop's `reconcileDesktopHalvesReport`, including package-marker creation and a second scan. Also exercise `/api/plugins/office-3d/state` through Hermes's dashboard loader. Use a local REST fixture for Home Assistant checks, not live devices.
- Query `/api/tools/toolsets` against isolated rendered default profiles on both hosts. Check requested rows are enabled and unrelated rows remain disabled. Exercise native `browser_exec` navigation and interaction, then stop its sessions; also exercise `web_search_tool`. Darwin evaluation and archive inspection do not prove browser execution on macOS.
- Inspect Linux service logs with `journalctl --user -u hermes-agent`, or approved `host_journal` access from a jail. macmini logs remain under `/var/log/hermes-agent.log`.

## rtk (shell-output compression)

`modules/programs/rtk.nix` (aspect `rtk`, in `user-base`) installs nixpkgs `rtk`, the full edition with the BUSL `engine` feature. No `pipeline.toml` is written, so it runs `rtk:default`: the bash rewrite plus per-command filters.

- **Claude**: a `PreToolUse` hook on `Bash` runs `rtk hook claude`, which rewrites supported commands (`git status` to `rtk git status`) through `updatedInput`. rtk returns `allow` only when one of our allow rules matched, and Claude still applies its deny and ask rules over a hook `allow`.
- **omp**: `~/.omp/agent/extensions/rtk.ts` is upstream's extension from `pkgs.rtk.src`, version-matched to the binary. It rewrites the command in place.
- **Rule twins**: Claude checks permission rules against the rewritten command, and omp's order is unverified. So `_bash.nix` gives each pattern not starting with `*` an `rtk <pattern>` twin with the same action. Without twins, `rtk nix run …` would slip past `nix run*` and land on the jailed `*` allow.
- **Hermes** (macmini) uses the `rtk-rewrite` plugin; see [Voice services](voice-services.md#hermes-agent). Laptop Hermes uses the official bubblewrap terminal backend without rtk rewriting.
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

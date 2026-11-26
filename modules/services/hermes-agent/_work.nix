# Hermes profiles for every Hermes host. Host differences live in _hosts.nix, _models.nix, _fallbacks.nix and _wikis.nix.
{
  inputs,
  models,
  fallbacks,
  disabledSkills,
  ...
}: {
  config,
  pkgs,
  lib,
  options,
  osConfig ? {},
  host,
  ...
}: let
  inherit (config.home) homeDirectory profileDirectory;
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  # The den host name keys every per-host table.
  hostKey = host.name;
  hostModels = models.${hostKey};
  hostCfg =
    (import ./_hosts.nix {
      inherit inputs lib pkgs osConfig;
      inherit (config.home) homeDirectory;
    }).${
      hostKey
    };
  bubblewrap = hostCfg.terminal == "bubblewrap";
  auxiliaryModel = model: (builtins.removeAttrs model ["default"]) // {model = model.default;};
  utilityModel = auxiliaryModel hostModels.default // {reasoning_effort = "low";};
  desktopSettings = pkgs.writeText "hermes-desktop-settings.json" (builtins.toJSON (import ./_desktop-settings.nix));
  root = "${homeDirectory}/.hermes";
  dev = "${homeDirectory}/dev";
  port = 8652;
  url = "http://127.0.0.1:${toString port}";
  package = import ./_package.nix {
    inherit lib;
    hermesInput = inputs.hermes-agent;
    system = pkgs.stdenv.hostPlatform.system;
    inherit (hostCfg) whatsappBridge;
  };
  roles = ["programmer" "reviewer" "qa" "research"];
  # People profiles beside augusto, who is the root (default) profile on every host.
  inherit (hostCfg) persons;
  sharedSkills = import ../../programs/agent-shared/_skills.nix {
    inherit lib pkgs;
    exclude = ["orchestrator"];
  };
  # The wiki trees this host mounts. A librarian exists only on its tree's curator host; writers file
  # sources into raw/ on every host that mounts the tree.
  wikis = import ./_wikis.nix;
  withPath = wiki: wiki // {path = "${homeDirectory}/${wiki.vault}";};
  hostWikis = map withPath (wikis.on hostKey);
  librarians = lib.listToAttrs (map (wiki: lib.nameValuePair wiki.librarian wiki) (lib.filter (wiki: wiki.curator == hostKey) hostWikis));
  # Programmer, QA and reviewer keep no persistent state, so each run starts from a fresh context.
  wikiReaders = ["research" "assistant"];
  writersOf = lib.listToAttrs (lib.concatMap (wiki: map (name: lib.nameValuePair name wiki) wiki.writers) hostWikis);
  wikiOf = lib.genAttrs wikiReaders (_: withPath wikis.trees.augusto) // writersOf // librarians;
  wikiProfiles = builtins.attrNames wikiOf;
  wikiWriters = builtins.attrNames writersOf ++ builtins.attrNames librarians;
  wikiGate = import ./_wiki-gate.nix {
    inherit pkgs lib;
    host = hostKey;
    home = homeDirectory;
    recallOnly = wikiReaders;
  };
  kanbanTranscripts = import ./_kanban-transcripts.nix {inherit lib;};
  # The desktop half mounts into Desktop's Kanban task modal, which has no SDK area: fail the build
  # when the markup it reads moves, instead of the list silently vanishing after a Hermes update.
  kanbanTranscriptsDesktop = pkgs.runCommand "kanban-transcripts-plugin.js" {} ''
    src=${inputs.hermes-agent}/apps/desktop/src
    check() {
      grep -qF -- "$2" "$src/$1" || {
        echo "kanban-transcripts: '$2' is gone from apps/desktop/src/$1; re-check desktop/plugin.js against the task modal" >&2
        exit 1
      }
    }
    check plugins/kanban/board.tsx '<TaskDrawer'
    check plugins/kanban/drawer.tsx '<header className='
    check plugins/kanban/drawer.tsx '{shortId(task.id)}'
    check plugins/kanban/drawer.tsx '<DialogTitle className='
    check plugins/kanban/drawer.tsx '<aside className='
    check plugins/kanban/ui.tsx ".replace(/^t_/, ''').slice(0, 6)"
    check plugins/kanban/ui.tsx "FIELD_LABEL = 'text-[0.62rem] font-semibold uppercase tracking-[0.14em] text-(--ui-text-quaternary)'"
    check components/ui/dialog.tsx 'data-slot="dialog-content"'
    check components/ui/dialog.tsx 'data-slot="dialog-title"'
    check components/ui/dialog.tsx 'bodyClassName?: string'
    cp ${./kanban-transcripts/desktop/plugin.js} $out
  '';
  # The default profile is the root Hermes home, not profiles/default.
  homeOf = name:
    if name == "default"
    then ".hermes"
    else ".hermes/profiles/${name}";
  # hwiki reads per-profile settings from $HERMES_HOME/hwiki.json.
  hwikiOf = name:
    lib.optionalAttrs (wikiOf ? ${name}) {
      hwiki =
        {
          wiki_path = wikiOf.${name}.path;
          memory_dir = wikis.sub wikiOf.${name} "memory";
          untrusted_dirs = lib.concatMap (wiki: [(wikis.sub wiki "raw") (wikis.sub wiki "review")]) (lib.filter (wiki: wiki.vault == wikiOf.${name}.vault) (builtins.attrValues wikis.trees));
          demote_paths = [(wikis.sub wikiOf.${name} "log.md") (wikis.sub wikiOf.${name} "memory/builtin-mirror.md")];
        }
        // lib.optionalAttrs (lib.elem name wikiReaders) {mirror_builtin_memory = false;};
    };
  inboxBase = wiki:
    pkgs.writeText "inbox.base" ''
      filters:
        and:
          - file.inFolder("${wikis.sub wiki "review"}")
          - not:
              - file.inFolder("${wikis.sub wiki "review/applied"}")
          - file.ext == "md"
      views:
        - type: table
          name: Inbox
          groupBy:
            property: note.status
            direction: ASC
          order:
            - file.name
            - note.status
            - note.revision
            - note.target
            - note.operation
            - note.contested
            - note.updated
    '';
  vaultSync = pkgs.writeShellApplication {
    name = "vault-sync";
    runtimeInputs = [pkgs.git pkgs.coreutils pkgs.gnugrep];
    text = builtins.readFile ./_vault-sync.sh;
  };
  # Cron scripts must be real files under the profile's scripts/; the bootstrap copies this one there.
  syncReport = wiki:
    pkgs.writeText "wiki-sync-report.sh" ''
      # The vault-sync timer's current failure; empty output is a silent run.
      ${pkgs.coreutils}/bin/cat ${lib.escapeShellArg "${wiki.path}/.git/vault-sync-report"} 2>/dev/null || true
    '';
  syncEnv = wiki:
    {
      WIKI_GATE = "${wikiGate}/gate.py";
      WIKI_PYTHON = lib.getExe pkgs.python3;
      WIKI_INBOX_BASE = "${inboxBase wiki}";
    }
    // lib.optionalAttrs (!(wiki.local or false)) {WIKI_TOKEN_FILE = config.sops.secrets.github_token.path;};
  agentPublicKey = lib.removeSuffix "\n" (builtins.readFile ../../programs/agent-jail/agent-ssh-key.pub);
  allowedSigners = pkgs.writeText "hermes-git-signers" ''
    ${config.programs.git.settings.user.email} ${agentPublicKey}
  '';
  # Terminal Git for work roles. One ssh-agent holds only the agent key. Bubblewrap unsets SSH_AUTH_SOCK,
  # so Git reaches the socket through core.sshCommand and a signing wrapper instead.
  inherit (hostCfg) runtimeDir gitAgentDir;
  gitAgentSocket = "${gitAgentDir}/agent.sock";
  gitAgent = pkgs.writeShellScript "hermes-git-agent" ''
    ${pkgs.coreutils}/bin/mkdir -p -m 0700 ${gitAgentDir}
    ${pkgs.coreutils}/bin/rm -f ${gitAgentSocket}
    ${lib.getExe' pkgs.openssh "ssh-agent"} -D -a ${gitAgentSocket} &
    agent=$!
    for _ in $(${pkgs.coreutils}/bin/seq 100); do
      [ -S ${gitAgentSocket} ] && break
      ${pkgs.coreutils}/bin/sleep 0.05
    done
    SSH_AUTH_SOCK=${gitAgentSocket} ${lib.getExe' pkgs.openssh "ssh-add"} -q ${config.sops.secrets.agent_ssh_key.path} || {
      kill "$agent"
      exit 1
    }
    wait "$agent"
  '';
  gitSign = pkgs.writeShellScript "hermes-git-sign" ''
    SSH_AUTH_SOCK=${gitAgentSocket} exec ${lib.getExe' pkgs.openssh "ssh-keygen"} "$@"
  '';
  agentPublicKeyFile = pkgs.writeText "agent-ssh-key.pub" "${agentPublicKey}\n";
  # From `gh api meta`; pinned so a sandbox never trusts a key on first use.
  githubKnownHosts = pkgs.writeText "github-known-hosts" ''
    github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
    github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
  '';
  # Routed workers build their terminal env from the profile's .env scope, not the gateway's process env,
  # so the config path travels like AGENT_GH_TOKEN: a secret file whose content is the value.
  agentGitConfigRef = pkgs.writeText "hermes-gitconfig-ref" "${agentGitConfig}";
  agentGitConfig = pkgs.writeText "hermes-gitconfig" (lib.generators.toGitINI {
    user = {
      inherit (config.programs.git.settings.user) name email;
      signingKey = "key::${agentPublicKey}";
    };
    gpg = {
      format = "ssh";
      ssh = {
        program = "${gitSign}";
        allowedSignersFile = "${allowedSigners}";
      };
    };
    commit.gpgSign = true;
    tag.gpgSign = true;
    core.sshCommand = lib.concatStringsSep " " [
      (lib.getExe pkgs.openssh)
      "-F /dev/null -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes"
      "-o IdentityAgent=${gitAgentSocket} -i ${agentPublicKeyFile} -o UserKnownHostsFile=${githubKnownHosts}"
    ];
  });
  plugin = pkgs.runCommand "hermes-workflow" {} ''
    mkdir -p $out
    cp ${./plugin}/*.py $out/
    cp ${./plugin/plugin.yaml} $out/plugin.yaml
    cp ${pkgs.writeText "settings.json" (builtins.toJSON {
      inherit port dev roles;
      extra_repos = ["${homeDirectory}/nixos"];
      google_token = "${root}/profiles/assistant/google_token.json";
    })} $out/settings.json
  '';
  # Hermes souls skip the harness context, which names Claude/omp mechanics. Every soul ends with
  # Caveman, as both harnesses do. Ponytail's change discipline applies to coding profiles: the
  # programmer and the people, who code at home.
  people = ["default"] ++ persons;
  # A writer hands ingest to the librarian on the curator host; elsewhere the librarian's daily ingest picks it up.
  handover = wiki:
    if wiki.curator == hostKey
    then "Hand them over with `delegate_task` routed to the `${wiki.librarian}` profile, passing the user's words unchanged."
    else "The librarian runs on the ${wiki.curator}; it ingests new sources on its daily run after the vault syncs, so tell the user the source is queued.";
  soul = name:
    pkgs.writeText "${name}-SOUL.md" ((
        if librarians ? ${name}
        then wikis.soul ./souls/librarian.md librarians.${name}
        else if lib.elem name people
        then builtins.readFile ./SOUL.md + lib.optionalString (name == "default") ("\n" + builtins.readFile ./souls/default.md)
        else builtins.readFile ./souls/${name}.md
      )
      + lib.optionalString (lib.elem name (roles ++ ["coordinator"])) (builtins.readFile ./souls/_role.md)
      + lib.optionalString (lib.elem name (roles ++ ["coordinator"])) (builtins.readFile ./souls/_skills.md)
      + lib.optionalString (lib.elem name (roles ++ ["coordinator"] ++ people)) (builtins.readFile hostCfg.executionSoul)
      + lib.optionalString (writersOf ? ${name}) (builtins.replaceStrings ["@handover@"] [(handover writersOf.${name})] (wikis.soul ./souls/_wiki.md writersOf.${name}))
      + builtins.readFile ./souls/_formatting.md
      + "\n# Evidence\n\n"
      + builtins.readFile ../../programs/agent-shared/evidence.md
      + lib.optionalString (lib.elem name (["programmer"] ++ people)) ("\n" + builtins.readFile ../../programs/agent-shared/style/ponytail.md)
      + "\n"
      + builtins.readFile ../../programs/agent-shared/style/caveman.md);
  # Catppuccin Mocha for the CLI; missing keys inherit the built-in default skin.
  skin = (pkgs.formats.yaml {}).generate "catppuccin-mocha.yaml" {
    name = "catppuccin-mocha";
    description = "Catppuccin Mocha";
    colors = {
      banner_border = "#cba6f7";
      banner_title = "#b4befe";
      banner_accent = "#89b4fa";
      banner_dim = "#6c7086";
      banner_text = "#cdd6f4";
      ui_accent = "#cba6f7";
      ui_label = "#94e2d5";
      ui_ok = "#a6e3a1";
      ui_error = "#f38ba8";
      ui_warn = "#fab387";
      prompt = "#cdd6f4";
      input_rule = "#585b70";
      response_border = "#89b4fa";
      session_label = "#b4befe";
      session_border = "#45475a";
      status_bar_bg = "#181825";
      voice_status_bg = "#181825";
      selection_bg = "#45475a";
      completion_menu_bg = "#181825";
      completion_menu_current_bg = "#313244";
      completion_menu_meta_bg = "#181825";
      completion_menu_meta_current_bg = "#313244";
    };
  };

  # Development caches and gh state the work repos need, bound read-write like the Claude/omp jail does.
  devBinds =
    map (path: {
      src = "${homeDirectory}/${path}";
      readonly = false;
    }) [".cache/nix" ".cache/pnpm" ".cache/gh" ".npm" ".cargo/registry" ".cargo/git" ".local/share/pnpm" ".local/state/pnpm" ".local/share/gh" ".local/state/gh" ".local/share/direnv"]
    ++ [
      {src = "${homeDirectory}/.config/direnv";}
      {src = "${runtimeDir}/podman";}
      {src = gitAgentDir;}
    ];
  # Upstream bubblewrap refuses any bind under these credential-list entries; the binds above need them.
  unhidden = [".cache" ".cargo" ".npm"];
  bubblewrapPlugin = pkgs.runCommand "hermes-bubblewrap" {} ''
    cp -r ${inputs.hermes-official-plugins}/bubblewrap $out
    chmod -R u+w $out
    substituteInPlace $out/home.py --replace-fail \
      'if path not in names:' \
      'if path not in names and os.path.relpath(path, home) not in UNHIDDEN_HOME_PATHS:'
    echo 'UNHIDDEN_HOME_PATHS = (${lib.concatMapStringsSep ", " (p: "\"${p}\"") unhidden},)' >> $out/home.py
    # Hermes strips GH_TOKEN, GITHUB_TOKEN and BASH_ENV from every terminal command, even when passed through,
    # so the token travels as AGENT_GH_TOKEN and every sandbox spawn restores it for gh. The agent Git config
    # travels as AGENT_GIT_CONFIG so host-side Git in the gateway (wiki-gate) keeps the user's config.
    substituteInPlace $out/sandbox.py --replace-fail \
      'env=_make_run_env(self.env),' \
      'env=_with_agent_gh_token(_make_run_env(self.env)),'
    cat ${agentGhTokenPatch} >> $out/sandbox.py
  '';
  agentGhTokenPatch = pkgs.writeText "agent-gh-token.py" ''


    def _with_agent_gh_token(env):
        if env.get("AGENT_GH_TOKEN"):
            env["GH_TOKEN"] = env["AGENT_GH_TOKEN"]
        if env.get("AGENT_GIT_CONFIG"):
            env["GIT_CONFIG_GLOBAL"] = env["AGENT_GIT_CONFIG"]
        return env
  '';
  officialPlugins = hostCfg.plugins;
  hasPlugin = name: lib.elem name officialPlugins;
  allToolsets = ["web" "browser" "terminal" "file" "code_execution" "vision" "video" "image_gen" "video_gen" "x_search" "tts" "skills" "todo" "kanban" "memory" "context_engine" "session_search" "connections" "clarify" "delegation" "cronjob" "discord" "discord_admin" "yuanbao" "computer_use" "workflow" "google" "security" "homeassistant" "office-3d" "a2a"];
  base = ["skills" "session_search" "office-3d"];
  # Programmer, QA and reviewer see only software-engineering skills in their index.
  workerDisabledSkills = [
    "computer-use"
    "hermes-agent"
    "architecture-diagram"
    "ascii-video"
    "baoyu-infographic"
    "claude-design"
    "manim-video"
    "p5js"
    "popular-web-designs"
    "songwriting-and-ai-music"
    "email-inbox-triage"
    "himalaya"
    "document-to-action-items"
    "google-workspace"
    "maps"
    "meeting-action-items"
    "microsoft-office"
    "pdf"
    "product-price-monitor"
    "teams-meeting-pipeline"
    "weekly-review-planning"
    "arxiv"
    "competitor-news-monitor"
    "youtube-content"
    "meeting-prep"
    "morning-brief"
    "obsidian"
    "xurl"
    "teach"
    "retro"
    "wait-what"
    "catch-up"
    "handoff"
    "grill-me"
    "grill-with-docs"
    "grilling"
    "sharpen"
    "to-questionnaire"
    "to-spec"
    "to-tickets"
    "triage"
    "wayfinder"
    "implement-spec"
    "improve-codebase-architecture"
    "setup-dev-skills"
    "wizard"
    "codebase-inspection"
    "github"
  ];
  work = base ++ ["kanban" "terminal" "file" "code_execution" "web" "todo"];
  # The root profile and every person share one toolset; hwiki exposes its tools and recall prompt only with memory.
  personal = ["browser" "clarify" "cronjob" "delegation" "terminal" "web" "kanban" "todo" "skills" "session_search" "a2a" "office-3d" "memory"];
  # The librarian of a tree this host curates, as a route for the profiles that hand ingest to it.
  wikiRoutes = builtins.attrNames librarians;
  # Augusto's tree is the only one on the laptop, so its single sync unit serves it.
  augustoWiki = withPath wikis.trees.augusto;
  profileConfig = {
    name,
    toolsets,
    rea ? false,
    security ? false,
    routes ? [],
  }: let
    # Home Assistant is a host plugin; on that host the people and the coordinator get its tools.
    allowed = toolsets ++ lib.optional (lib.elem name hostCfg.homeassistant) "homeassistant";
  in {
    model = hostModels.${name};
    fallback_providers = fallbacks.${hostKey}.${name};
    agent = {
      disabled_toolsets = lib.subtractLists allowed allToolsets;
      clarify_timeout = 0;
    };
    auxiliary = {
      # Compression keeps the conversation's meaning, so it runs on the profile's own model.
      compression = {
        provider = "main";
        model = "";
      };
      approval = utilityModel;
      title_generation = utilityModel;
    };
    platform_toolsets.cli = allowed;
    toolsets = lib.optional (lib.elem "kanban" allowed) "kanban";
    approvals = {
      mode = "off";
      deny = ["*nixos-rebuild*" "*darwin-rebuild*"];
    };
    terminal = {
      backend = hostCfg.terminal;
      degraded_mode = "fail";
      # Every session starts here, kanban workers included: a card's workspace does not move the
      # bubblewrap cwd. Workers reach their checkout through the ~/dev bind below.
      cwd = "${dev}/.hermes-workspaces/${name}";
      env_passthrough = ["NIX_REMOTE"] ++ lib.optionals (lib.elem name (["coordinator"] ++ roles)) ["AGENT_GH_TOKEN" "AGENT_GIT_CONFIG" "DOCKER_HOST" "CONTAINER_HOST" "PNPM_CONFIG_NPMRC_AUTH_FILE"];
    };
    browser = lib.optionalAttrs (lib.elem "browser" toolsets) {
      executable_path =
        if isLinux
        then lib.getExe pkgs.chromium
        else "${pkgs.playwright-driver.components.chromium}/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing";
      cloud_provider = "local";
      engine = "auto";
      use_real_profile = false;
    };
    # Bubblewrap isolates terminal commands, not the separate browser process.
    bot_desktop = lib.optionalAttrs (lib.elem "browser" toolsets) {placement = "gateway";};
    web = lib.optionalAttrs (lib.elem "web" toolsets) {
      backend = "exa";
      provider_tier.exa = "free";
    };
    security.allow_lazy_installs = false;
    display = {
      vim_mode = true;
      skin = "catppuccin-mocha";
      streaming = true;
      bell_on_prompt = true;
    };
    skills = {
      external_dirs = ["${sharedSkills.package}" "${./skills}"];
      disabled = disabledSkills;
    };
    plugins = {
      enabled =
        ["rtk-rewrite" "hermes-workflow" "advanced-delegation" "office-3d" "wiki-gate" "kanban-transcripts"]
        ++ lib.optional bubblewrap "bubblewrap"
        ++ lib.optional security "hermes-security"
        ++ lib.optional rea "rea"
        ++ lib.optional (lib.elem "homeassistant" allowed) "homeassistant";
      entries = lib.optionalAttrs bubblewrap {
        bubblewrap.settings = {
          profile = "network";
          home_default_deny = "all";
          # File tools run in this sandbox too. Only the vault folders a profile writes are bound, and a
          # librarian bound to a whole vault has its .git hidden, so no sandbox can plant Git hooks or
          # config that the sync timer would run.
          hide =
            ["/run/secrets" "${homeDirectory}/.config/sops" "${config.sops.secrets.agent_ssh_key.path}"]
            ++ lib.optional (librarians ? ${name}) "${wikiOf.${name}.path}/.git";
          binds =
            lib.optional (lib.elem name wikiWriters) {
              src = lib.removeSuffix "/" "${wikiOf.${name}.path}/${wikis.sub wikiOf.${name} (lib.optionalString (!(librarians ? ${name})) "raw")}";
              readonly = false;
            }
            # Card checkouts live under ~/dev, outside terminal.cwd, the only path the backend binds itself.
            # Tradeoff: these profiles can read and write every repository under ~/dev, its .git included.
            ++ lib.optional (lib.elem name (["coordinator"] ++ roles)) {
              src = dev;
              readonly = false;
            }
            ++ lib.optionals (lib.elem name (["coordinator"] ++ roles)) devBinds;
          # AS and CPU apply per process, NPROC per sandbox. Rust builds in these roles failed at 4096 MB
          # ("LLVM ERROR: out of memory") and 256 processes (thread spawn EAGAIN).
          memory_mb =
            if lib.elem name ["programmer" "reviewer"]
            then 16384
            else 4096;
          cpu_seconds =
            if lib.elem name ["programmer" "reviewer"]
            then 3600
            else 600;
          max_procs =
            if lib.elem name ["programmer" "reviewer"]
            then 4096
            else 256;
        };
        claude-subscription-directsdk-experimental.settings = {
          claude_config_dir = "${homeDirectory}/.claude";
          extra_usage = "stop";
          max_concurrent = 4;
        };
        hermes-security.allow_gateway_injection = security;
      };
    };
    delegation = {
      backend =
        if routes != []
        then "profile_routes"
        else "default";
      backends.profile_routes.profiles = map (route: {name = route;}) routes;
    };
    # Bootstrap merges into the existing config, so profiles without memory clear every memory source explicitly.
    memory =
      if lib.elem "memory" allowed
      then {provider = lib.optionalString (lib.elem name wikiProfiles) "hwiki";}
      else {
        provider = "";
        memory_enabled = false;
        user_profile_enabled = false;
      };
    mcp_servers =
      {
        host.enabled = false;
      }
      // lib.optionalAttrs (hasPlugin "rea") {
        rea = {
          enabled = rea;
          command = lib.getExe' pkgs.nodejs "npx";
          args = ["-y" "rea-agents@6.7.0" "mcp"];
          # Analysis only: execution/debugger tools do not use the terminal sandbox.
          tools.include = [
            "open_binary"
            "analyze_function"
            "inspect_binary_layout"
            "inspect_recorded_crash"
            "inspect_go_binary"
            "inspect_rust_binary"
            "inspect_electron_fuses"
            "analyze_javascript_application"
            "inspect_android_package"
            "inspect_sqlite_database"
          ];
        };
      };
  };
  workMcpUrls = {
    linear = "https://mcp.linear.app/mcp";
    notion = "https://mcp.notion.com/mcp";
    datadog = "https://mcp.datadoghq.eu/v1/mcp";
  };
  # Bootstrap merges into existing configs, so a host without the work MCPs disables them instead of dropping them.
  workMcp = url:
    if hostCfg.workMcp
    then {
      inherit url;
      auth = "oauth";
      trust = "full";
    }
    else {enabled = false;};
  profiles =
    {
      coordinator = {
        description = "Plans work with the user, routes native Hermes roles.";
        config =
          lib.recursiveUpdate (profileConfig {
            name = "coordinator";
            toolsets = work ++ ["memory" "clarify" "workflow" "delegation" "cronjob"];
            routes = roles ++ lib.filter (route: route == "librarian") wikiRoutes;
          }) {
            mcp_servers = {
              linear = workMcp workMcpUrls.linear;
              notion = workMcp workMcpUrls.notion;
              datadog = workMcp workMcpUrls.datadog;
            };
          };
        soul = soul "coordinator";
        secrets.AGENT_GH_TOKEN = config.sops.secrets.github_token.path;
        secrets.AGENT_GIT_CONFIG = "${agentGitConfigRef}";
        plugin = true;
      };
      assistant = {
        description = "Reads mail and calendar and writes briefs. Incoming content never authorizes engineering work.";
        config = profileConfig {
          name = "assistant";
          toolsets = base ++ ["memory" "kanban" "cronjob" "google"];
        };
        soul = soul "assistant";
        plugin = true;
      };
    }
    // lib.mapAttrs (name: wiki: {
      description = "Curates the ${wiki.tree} wiki: turns raw sources into proposals, sends the digest and applies approved proposals.";
      config = lib.recursiveUpdate (profileConfig ({
          inherit name;
          toolsets = ["file" "skills" "memory"];
        }
        # Livia's librarian may ask research for sources; no librarian reaches the coding roles.
        // lib.optionalAttrs (wiki.tree == "livia") {
          toolsets = ["file" "skills" "memory" "delegation"];
          routes = ["research"];
        })) {
        skills.external_dirs = ["${sharedSkills.package}" "${./skills}" "${./wiki-skills}"];
      };
      soul = soul name;
      plugin = true;
      scripts."wiki-sync-report.sh" = "${syncReport wiki}";
      # Output goes to the librarian's Bot Chat plus every home channel connected at runtime. Telegram
      # is set up by hand; `all` resolves at fire time and skips pre-dispatch checks, so an
      # unconfigured channel never blocks a run. llm-wiki-review keeps these turns verdict-free.
      cron =
        map (job:
          job
          // {
            skills = ["llm-wiki" "llm-wiki-review" "writing-for-agents"];
            deliver = "bot-chat,all";
          }) [
          {
            name = "wiki-ingest";
            schedule = "0 7 * * *";
            prompt = "Run the llm-wiki-review ingest on the ${wiki.tree} tree and reply with the digest.";
          }
          {
            name = "wiki-lint";
            schedule = "0 8 * * 1";
            prompt = "Run the read-only llm-wiki-review lint on the ${wiki.tree} tree and reply with the report.";
          }
          {
            name = "wiki-memory";
            schedule = "0 9 * * 3";
            prompt = "Run the llm-wiki-review memory maintenance on the ${wiki.tree} tree and reply with a terse summary.";
          }
        ]
        ++ [
          {
            # Reports the sync timer's failure each quarter hour until a sync succeeds.
            name = "wiki-sync-report";
            schedule = "5,20,35,50 * * * *";
            prompt = "";
            skills = [];
            deliver = "bot-chat,all";
            no_agent = true;
            script = "wiki-sync-report.sh";
          }
        ];
    })
    librarians
    // lib.genAttrs roles (name: {
      description =
        {
          programmer = "Implements tickets and fixes bugs directly, verifies changes and requests independent review.";
          reviewer = "Reviews changes independently, publishes authorized approved work and verifies required CI.";
          qa = "Exercises changes directly with end-to-end and manual-style checks.";
          research = "Investigates primary sources and repositories and returns evidence-backed findings.";
        }.${
          name
        };
      config =
        lib.recursiveUpdate (profileConfig {
          inherit name;
          toolsets =
            work
            ++ lib.optionals (name == "qa") ["browser" "vision"]
            ++ lib.optional (name == "research") "memory"
            ++ lib.optional (hasPlugin "hermes-security" && name == "reviewer") "security"
            # Every role may spawn plain subagents; only the reviewer routes to other profiles, whose credentials a route lends.
            ++ ["delegation"];
          rea = hasPlugin "rea" && name == "research";
          security = hasPlugin "hermes-security" && name == "reviewer";
          routes = lib.optionals (name == "reviewer") roles;
        }) {
          skills.disabled = disabledSkills ++ lib.optionals (name != "research") (workerDisabledSkills ++ lib.optional (name != "qa") "dogfood");
          # Cards cite tickets, docs and production evidence; workers read them. Writes stay with the coordinator.
          mcp_servers = lib.mapAttrs (server: tools: workMcp workMcpUrls.${server} // lib.optionalAttrs hostCfg.workMcp {tools.include = tools;}) {
            linear = [
              "get_issue"
              "list_issues"
              "list_comments"
              "get_attachment"
              "extract_images"
              "get_document"
              "list_documents"
              "get_project"
              "list_projects"
              "get_milestone"
              "list_milestones"
              "get_team"
              "list_teams"
              "get_user"
              "list_users"
              "get_issue_status"
              "list_issue_statuses"
              "list_issue_labels"
              "list_cycles"
            ];
            notion = [
              "notion-search"
              "notion-fetch"
              "notion-get-comments"
              "notion-get-users"
              "notion-get-teams"
              "notion-get-self"
              "notion-query-data-sources"
              "notion-query-multiple-data-sources"
              "notion-query-meeting-notes"
              "notion-list-page-backlinks"
              "notion-download-attachment"
              "notion-get-file-download-urls"
            ];
            datadog = [
              "list_datadog_skills"
              "load_datadog_skill"
              "search_datadog_sdk"
              "execute_code"
              "search_datadog_logs"
              "analyze_datadog_logs"
              "search_datadog_spans"
              "aggregate_spans"
              "get_datadog_trace"
              "search_datadog_metrics"
              "get_datadog_metric"
              "get_datadog_metric_context"
              "search_datadog_monitors"
              "search_datadog_incidents"
              "get_datadog_incident"
              "search_datadog_events"
              "aggregate_events"
              "search_datadog_rum_events"
              "aggregate_rum_events"
              "search_datadog_hosts"
              "search_datadog_entities"
              "search_datadog_dashboards"
              "get_datadog_dashboard"
              "search_datadog_notebooks"
              "get_datadog_notebook"
              "get_change_stories"
            ];
          };
        };
      soul = soul name;
      secrets.AGENT_GH_TOKEN = config.sops.secrets.github_token.path;
      secrets.AGENT_GIT_CONFIG = "${agentGitConfigRef}";
      plugin = true;
    })
    // lib.genAttrs persons (name: {
      description = "${name}'s personal assistant.";
      config = profileConfig {
        inherit name;
        toolsets = personal;
        # A person hands wiki work to their own tree's librarian and never routes to the coding roles.
        routes = lib.optional (librarians ? ${writersOf.${name}.librarian or ""}) writersOf.${name}.librarian;
      };
      soul = soul name;
      plugin = true;
    });
  inherit (hostCfg) apiServer;
  # Profile environment Nix owns; bootstrap also drops every API_SERVER_* key it does not set here.
  envOf = name:
    lib.optionalAttrs ((hostModels.${name}.base_url or "") == "http://127.0.0.1:11434/v1") {OPENAI_API_KEY = "ollama";}
    // lib.optionalAttrs (lib.elem name hostCfg.homeassistant) {HASS_URL = "http://home.local:8123";}
    # The gateway loads the root .env into its own process, which serves every profile, so the
    # root's wiki paths come only from its hwiki.json.
    // lib.optionalAttrs (wikiOf ? ${name} && name != "default") {
      OBSIDIAN_VAULT_PATH = wikiOf.${name}.path;
      WIKI_PATH = lib.removeSuffix "/" "${wikiOf.${name}.path}/${wikis.sub wikiOf.${name} ""}";
    }
    // lib.optionalAttrs (apiServer != null && apiServer.keys ? ${name}) {API_SERVER_MODEL_NAME = "hermes-agent";}
    // lib.optionalAttrs (apiServer != null && name == "default") {
      API_SERVER_ENABLED = "true";
      API_SERVER_HOST = "127.0.0.1";
      API_SERVER_PORT = apiServer.port;
    };
  apiKeyOf = name: lib.optionalAttrs (apiServer != null && apiServer.keys ? ${name}) {API_SERVER_KEY = apiServer.keys.${name};};
  manifest = pkgs.writeText "hermes-profiles.json" (builtins.toJSON {
    plugin = "${root}/nix/plugins/hermes-workflow";
    inherit (hostCfg) provider;
    skins."catppuccin-mocha" = "${skin}";
    office = {
      source = toString inputs.hermes-plugin-office-3d;
      revision = inputs.hermes-plugin-office-3d.rev;
      profiles = builtins.attrNames profiles;
    };
    profiles = lib.mapAttrs (name: managed:
      managed
      // {
        # Skills are Nix-managed; only the coordinator and default edit them, so skill_manage leaves the others' prompts.
        defer = lib.optional (name != "coordinator") "skill_manage";
        env = envOf name;
        secrets = managed.secrets or {} // apiKeyOf name;
      }
      // hwikiOf name)
    profiles;
    root =
      {
        config =
          lib.recursiveUpdate (profileConfig {
            name = "default";
            toolsets = personal;
            routes = roles ++ lib.filter (route: route == "librarian") wikiRoutes;
          }) {
            gateway.multiplex_profiles = true;
            kanban = {
              dispatch_in_gateway = true;
              dispatch_profiles = roles ++ ["coordinator"];
              auto_decompose = false;
              orchestrator_profile = "coordinator";
              default_assignee = "coordinator";
            };
            auxiliary = {
              kanban_decomposer = auxiliaryModel hostModels.coordinator;
              triage_specifier = auxiliaryModel hostModels.coordinator;
            };
          };
        soul = soul "default";
        plugin = true;
        env = envOf "default";
        secrets = apiKeyOf "default";
      }
      // hwikiOf "default";
  });
  bootstrapLib = pkgs.linkFarm "hermes-bootstrap" [
    {
      name = "_bootstrap.py";
      path = ./_bootstrap.py;
    }
  ];
  bootstrap = pkgs.writeShellScript "hermes-bootstrap" ''
    set -eu
    umask 077
    PYTHONPATH=${bootstrapLib} exec ${package.hermesVenv}/bin/python ${./_bootstrap_work.py} ${manifest}
  '';
  hermes = pkgs.writeShellScriptBin "hermes" ''
    export HERMES_HOME=${lib.escapeShellArg root}
    ${lib.concatStrings (lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}\n") hostCfg.wrapperEnv)}
    mkdir -p ${lib.escapeShellArgs hostCfg.wrapperDirs} ${lib.escapeShellArg gitAgentDir}
    unset AGENT_JAIL_SIGNING SSH_AUTH_SOCK GPG_AGENT_INFO
    ${bootstrap}
    exec ${lib.getExe package} "$@"
  '';
in
  lib.mkMerge [
    {
      home.packages =
        [
          hermes
        ]
        ++ lib.optionals isLinux (lib.optional bubblewrap pkgs.bubblewrap ++ [pkgs.util-linux pkgs.nodejs])
        ++ lib.optionals hostCfg.desktop [
          # Upstream's desktop runs its own 0.0.0 build, whose plugin version gate skips bubblewrap: no terminal backend, no file tools.
          # The profile path, not the store path: Desktop outlives switches and respawns the gateway, and a
          # store path would keep launching the previous generation's wrapper and environment.
          (package.hermesDesktop.override {extraEnv.HERMES_DESKTOP_HERMES = "/etc/profiles/per-user/${config.home.username}/bin/hermes";})
        ];
      home.file =
        lib.listToAttrs (lib.concatMap (home:
          (map (name:
            lib.nameValuePair "${home}/plugins/${name}" {
              source =
                if name == "bubblewrap"
                then bubblewrapPlugin
                else "${inputs.hermes-official-plugins}/${name}";
            })
          officialPlugins)
          ++ [
            (lib.nameValuePair "${home}/plugins/office-3d" {source = inputs.hermes-plugin-office-3d;})
            (lib.nameValuePair "${home}/plugins/wiki-gate" {source = wikiGate;})
            (lib.nameValuePair "${home}/plugins/kanban-transcripts" {source = kanbanTranscripts;})
            # Upstream's adapter, version-matched to the binary; see the deny twins in profileConfig.
            (lib.nameValuePair "${home}/plugins/rtk-rewrite" {source = "${pkgs.rtk.src}/hooks/hermes/rtk-rewrite";})
          ])
        ([".hermes"] ++ map (name: ".hermes/profiles/${name}") (builtins.attrNames profiles)))
        // lib.listToAttrs (map (name: lib.nameValuePair "${homeOf name}/plugins/hwiki" {source = inputs.hermes-plugin-hwiki;}) wikiProfiles)
        // lib.mapAttrs' (name: image: lib.nameValuePair "${homeOf name}/assets/avatar.png" {source = ./assets/${image};}) ({
            default = "hermes.png";
            coordinator = "hermes-manager.png";
            assistant = "hermes-assistant.png";
            programmer = "hermes-programmer.png";
            reviewer = "hermes-reviewer.png";
            qa = "hermes-qa.png";
            research = "hermes-researcher.png";
          }
          // lib.mapAttrs (_: _: "hermes-librarian.png") librarians)
        // {
          ".hermes/nix/plugins/hermes-workflow".source = plugin;
          # Desktop cannot stamp its package marker into a copy of a read-only store directory.
          ".hermes/desktop-plugins/office-3d/plugin.js".source = "${inputs.hermes-plugin-office-3d}/desktop/plugin.js";
          ".hermes/desktop-plugins/kanban-transcripts/plugin.js".source = kanbanTranscriptsDesktop;
        };
      # A local vault has no clone to start from; the sync timer adds the baseline and commits.
      home.activation.wiki-vaults = lib.hm.dag.entryAfter ["writeBoundary"] (lib.concatMapStrings (wiki:
        lib.optionalString (wiki.local or false) ''
          if [ ! -e ${lib.escapeShellArg "${wiki.path}/.git"} ]; then
            run install -d -m 0700 ${lib.escapeShellArg wiki.path}
            run ${lib.getExe pkgs.git} init -q -b main ${lib.escapeShellArg wiki.path}
          fi
        '')
      hostWikis);
      home.activation.hermes-dirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run mkdir -p ${lib.escapeShellArg root} ${lib.escapeShellArg dev}
        run chmod 0700 ${lib.escapeShellArg root}
        run ${package.hermesVenv}/bin/python -c \
          'import json, sys; from pathlib import Path; from hermes_cli.ui_preferences import write_preferences; write_preferences(json.loads(Path(sys.argv[1]).read_text()), path=Path(sys.argv[2]))' \
          ${desktopSettings} ${lib.escapeShellArg "${root}/ui-preferences.json"}
      '';
      systemd.user.services = lib.optionalAttrs isLinux {
        # Hermes clients look for exactly this unit name and start it instead of spawning their own gateway.
        hermes-gateway = {
          Unit = {
            Description = "Hermes Agent gateway";
            X-RestartIfChanged = false;
            Wants = ["hermes-git-agent.service"];
            After = ["hermes-git-agent.service"];
          };
          Service = {
            Environment = ["HERMES_HOME=${root}" "PATH=${profileDirectory}/bin:/run/current-system/sw/bin"];
            WorkingDirectory = dev;
            ExecStart = "${lib.getExe hermes} -p default gateway run";
            Restart = "on-failure";
            RestartSec = 10;
          };
          Install.WantedBy = ["default.target"];
        };
        hermes-git-agent = {
          Unit.Description = "SSH agent holding only the Hermes agent key";
          Service = {
            ExecStart = "${gitAgent}";
            Restart = "on-failure";
            RestartSec = 5;
          };
          Install.WantedBy = ["default.target"];
        };
        wiki-sync = {
          Unit.Description = "Audit, commit and sync the wiki vault";
          Service = {
            Type = "oneshot";
            Environment = lib.mapAttrsToList (name: value: "${name}=${value}") (syncEnv augustoWiki);
            ExecStart = "${lib.getExe vaultSync} ${augustoWiki.path} ${augustoWiki.tree} ${augustoWiki.dir}";
          };
        };
      };
      systemd.user.timers = lib.optionalAttrs isLinux {
        wiki-sync = {
          Unit.Description = "Sync the wiki vault every 15 minutes";
          Timer = {
            OnCalendar = "*:0/15";
            Persistent = true;
          };
          Install.WantedBy = ["timers.target"];
        };
      };
      launchd.agents = lib.optionalAttrs (!isLinux) (lib.listToAttrs (map (wiki:
          lib.nameValuePair "wiki-sync-${wiki.tree}" {
            enable = true;
            config = {
              ProgramArguments = [(lib.getExe vaultSync) wiki.path wiki.tree wiki.dir];
              EnvironmentVariables = syncEnv wiki;
              StartInterval = 900;
              RunAtLoad = true;
              StandardOutPath = "${homeDirectory}/Library/Logs/wiki-sync-${wiki.tree}.log";
              StandardErrorPath = "${homeDirectory}/Library/Logs/wiki-sync-${wiki.tree}.log";
            };
          })
        hostWikis)
        // {
          # Linux runs this as the hermes-git-agent user service. A LaunchAgent starts at login, so until the
          # user logs in on the macmini, Git there has no agent key.
          hermes-git-agent = {
            enable = true;
            config = {
              ProgramArguments = ["${gitAgent}"];
              KeepAlive = true;
              RunAtLoad = true;
              StandardOutPath = "${homeDirectory}/Library/Logs/hermes-git-agent.log";
              StandardErrorPath = "${homeDirectory}/Library/Logs/hermes-git-agent.log";
            };
          };
        });
      # A local terminal runs Git with the user's own config, so a host without the YubiKey takes the agent identity.
      programs.git.includes = lib.optional hostCfg.agentGit {path = "${agentGitConfig}";};
      # Hermes strips GH_TOKEN from terminal commands, so gh reads the agent token from its hosts file instead.
      sops.templates = lib.optionalAttrs hostCfg.agentGit {
        "gh-hosts.yml" = {
          path = "${config.xdg.configHome}/gh/hosts.yml";
          content = ''
            github.com:
              oauth_token: ${config.sops.placeholder.github_token}
              git_protocol: ssh
          '';
        };
      };
    }
    (lib.optionalAttrs (options ? herdr) {
      herdr.programs.hermes = {
        name = "Hermes";
        icon = "icons/hermes.svg";
        tint = true;
        tile = "#1c1d21";
        color = "#ffffff";
        run = ["hermes" "-p" "coordinator"];
      };
      herdr.keys."super-s" = "terminal.open:hermes";
    })
    (lib.optionalAttrs (options.programs ? claude-code) {
      programs.claude-code.mcpServers.hermes-board = {
        command = lib.getExe pkgs.python3;
        args = ["${./mcp.py}" url];
      };
    })
    (lib.optionalAttrs (options ? omp) {
      omp.mcpServers.hermes-board = {
        type = "stdio";
        command = lib.getExe pkgs.python3;
        args = ["${./mcp.py}" url];
      };
    })
  ]

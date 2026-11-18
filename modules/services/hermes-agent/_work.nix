# Shared work profiles; host-specific services and terminal backends stay separate.
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
  ...
}: let
  inherit (config.home) homeDirectory profileDirectory;
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  host =
    if isLinux
    then "laptop"
    else "macmini";
  hostModels = models.${host};
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
    whatsappBridge = !isLinux;
  };
  roles = ["programmer" "reviewer" "qa" "research"];
  sharedSkills = import ../../programs/agent-shared/_skills.nix {
    inherit lib pkgs;
    exclude = ["orchestrator"];
  };
  # Each librarian curates one tree of this host. On the laptop the coordinator files sources
  # into the work tree and default and the roles only recall it; the macmini household profiles live in _darwin.nix.
  wikis = import ./_wikis.nix;
  librarians = lib.mapAttrs' (_: wiki: lib.nameValuePair wiki.librarian (wiki // {path = "${homeDirectory}/${wiki.vault}";})) wikis.trees.${host};
  wikiReaders = lib.optionals isLinux (["default"] ++ roles);
  wikiOf = librarians // lib.optionalAttrs isLinux (lib.genAttrs (["coordinator"] ++ wikiReaders) (_: librarians.librarian));
  wikiProfiles = builtins.attrNames wikiOf;
  wikiWriters = lib.optionals isLinux ["coordinator" "librarian"];
  wikiGate = import ./_wiki-gate.nix {
    inherit pkgs lib host;
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
          memory_dir = "${wikiOf.${name}.tree}/memory";
          untrusted_dirs = lib.concatMap (tree: ["${tree}/raw" "${tree}/review"]) (wikis.treesIn wikiOf.${name}.vault);
          demote_paths = ["log.md" "${wikiOf.${name}.tree}/memory/builtin-mirror.md"];
        }
        // lib.optionalAttrs (lib.elem name wikiReaders) {mirror_builtin_memory = false;};
    };
  inboxBase = tree:
    pkgs.writeText "inbox.base" ''
      filters:
        and:
          - file.inFolder("${tree}/review")
          - not:
              - file.inFolder("${tree}/review/applied")
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
      WIKI_INBOX_BASE = "${inboxBase wiki.tree}";
    }
    // lib.optionalAttrs (!(wiki.local or false)) {WIKI_TOKEN_FILE = config.sops.secrets.github_token.path;};
  agentPublicKey = lib.removeSuffix "\n" (builtins.readFile ../../programs/agent-jail/agent-ssh-key.pub);
  allowedSigners = pkgs.writeText "hermes-git-signers" ''
    ${config.programs.git.settings.user.email} ${agentPublicKey}
  '';
  plugin = pkgs.runCommand "hermes-workflow" {} ''
    mkdir -p $out
    cp ${./plugin}/*.py $out/
    cp ${./plugin/plugin.yaml} $out/plugin.yaml
    cp ${pkgs.writeText "settings.json" (builtins.toJSON {
      inherit port dev roles;
      extra_repos = ["${homeDirectory}/nixos"];
      git = lib.getExe pkgs.git;
      ssh = lib.getExe pkgs.openssh;
      ssh_agent = lib.getExe' pkgs.openssh "ssh-agent";
      ssh_add = lib.getExe' pkgs.openssh "ssh-add";
      ssh_keygen = lib.getExe' pkgs.openssh "ssh-keygen";
      gpg = lib.getExe pkgs.gnupg;
      agent_key = config.sops.secrets.agent_ssh_key.path;
      agent_public_key = agentPublicKey;
      allowed_signers = "${allowedSigners}";
      user_name = config.programs.git.settings.user.name;
      user_email = config.programs.git.settings.user.email;
      human_signer = config.programs.git.signing.key;
      known_hosts = "${homeDirectory}/.ssh/known_hosts";
      google_token = "${root}/profiles/assistant/google_token.json";
    })} $out/settings.json
  '';
  # Hermes souls skip the harness context and Caveman: both contradict _formatting.md or name
  # Claude/omp mechanics. Ponytail's change discipline applies to the programmer only.
  soul = name:
    pkgs.writeText "${name}-SOUL.md" ((
        if librarians ? ${name}
        then wikis.soul ./souls/librarian.md librarians.${name}
        else builtins.readFile ./souls/${name}.md
      )
      + lib.optionalString (lib.elem name (roles ++ ["coordinator"])) (builtins.readFile ./souls/_role.md)
      + lib.optionalString (lib.elem name (roles ++ ["coordinator"])) (builtins.readFile ./souls/_skills.md)
      + lib.optionalString (lib.elem name (roles ++ ["coordinator" "default"])) (builtins.readFile (
        if isLinux
        then ./souls/_linux.md
        else ./souls/_darwin.md
      ))
      + lib.optionalString (isLinux && name == "coordinator") (wikis.soul ./souls/_wiki.md wikiOf.coordinator)
      + builtins.readFile ./souls/_formatting.md
      + builtins.readFile ./souls/_evidence.md
      + lib.optionalString (name == "programmer") ("\n" + builtins.readFile ../../programs/agent-shared/style/ponytail.md));
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
  # shortcut: assumes uid 1000 for the Podman socket; derive it if the user's uid ever changes.
  runtimeDir = "/run/user/1000";
  devBinds =
    map (path: {
      src = "${homeDirectory}/${path}";
      readonly = false;
    }) [".cache/nix" ".cache/pnpm" ".cache/gh" ".npm" ".cargo/registry" ".cargo/git" ".local/share/pnpm" ".local/state/pnpm" ".local/share/gh" ".local/state/gh" ".local/share/direnv"]
    ++ [
      {src = "${homeDirectory}/.config/direnv";}
      {src = "${runtimeDir}/podman";}
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
    # so the token travels as AGENT_GH_TOKEN and every sandbox spawn restores it for gh.
    substituteInPlace $out/sandbox.py --replace-fail \
      'env=_make_run_env(self.env),' \
      'env=_with_agent_gh_token(_make_run_env(self.env)),'
    cat ${agentGhTokenPatch} >> $out/sandbox.py
  '';
  agentGhTokenPatch = pkgs.writeText "agent-gh-token.py" ''


    def _with_agent_gh_token(env):
        if env.get("AGENT_GH_TOKEN"):
            env["GH_TOKEN"] = env["AGENT_GH_TOKEN"]
        return env
  '';
  # pnpm reads registry auth from this file instead of ~/.npmrc, which the sandbox hides.
  npmrcAuth = pkgs.writeText "npmrc" "//npm.pkg.github.com/:_authToken=\${NELLY_GH_REGISTRY_TOKEN}\n";
  officialPlugins =
    ["advanced-delegation"]
    ++ (
      if isLinux
      then ["bubblewrap" "hermes-security" "rea"]
      else ["homeassistant"]
    );
  allToolsets = ["web" "browser" "terminal" "file" "code_execution" "vision" "video" "image_gen" "video_gen" "x_search" "tts" "skills" "todo" "kanban" "memory" "context_engine" "session_search" "connections" "clarify" "delegation" "cronjob" "discord" "discord_admin" "yuanbao" "computer_use" "git" "workflow" "google" "security" "homeassistant" "office-3d" "a2a"];
  base = ["skills" "memory" "session_search" "office-3d"];
  work = base ++ ["kanban" "terminal" "file" "code_execution" "web" "git" "todo"];
  profileConfig = {
    name,
    toolsets,
    rea ? false,
    security ? false,
    delegate ? false,
  }: {
    model = hostModels.${name};
    fallback_providers = fallbacks.${host}.${name};
    agent = {
      reasoning_effort = "medium";
      disabled_toolsets = lib.subtractLists toolsets allToolsets;
    };
    auxiliary = {
      compression = utilityModel;
      approval = utilityModel;
      title_generation = utilityModel;
    };
    platform_toolsets.cli = toolsets;
    toolsets = lib.optional (lib.elem "kanban" toolsets) "kanban";
    approvals = {
      mode = "off";
      # rtk-rewrite turns `git status` into `rtk git status` before this check; the `rtk git` twins catch it.
      deny = ["*nixos-rebuild*" "*darwin-rebuild*" "git" "git *" "*/git" "*/git *" "rtk git" "rtk git *"];
    };
    terminal = {
      backend =
        if isLinux
        then "bubblewrap"
        else "local";
      degraded_mode = "fail";
      # Every session starts here, kanban workers included: a card's workspace does not move the
      # bubblewrap cwd. Workers reach their checkout through the ~/dev bind below.
      cwd = "${dev}/.hermes-workspaces/${name}";
      env_passthrough = ["NIX_REMOTE"] ++ lib.optionals (lib.elem name (["coordinator"] ++ roles)) ["AGENT_GH_TOKEN" "DOCKER_HOST" "CONTAINER_HOST" "PNPM_CONFIG_NPMRC_AUTH_FILE"];
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
        ++ lib.optional isLinux "bubblewrap"
        ++ lib.optional (isLinux && security) "hermes-security"
        ++ lib.optional (isLinux && rea) "rea"
        ++ lib.optional (!isLinux && name == "coordinator") "homeassistant";
      entries = lib.optionalAttrs isLinux {
        bubblewrap.settings = {
          profile = "network";
          home_default_deny = "all";
          hide = ["/run/secrets" "${homeDirectory}/.config/sops" "${config.sops.secrets.agent_ssh_key.path}"];
          # File tools run in this sandbox too. Only the vault folders a profile writes are bound,
          # so no sandbox can plant Git hooks or config that the sync timer would run.
          binds =
            lib.optional (lib.elem name wikiWriters) {
              src =
                if name == "librarian"
                then "${librarians.librarian.path}/${librarians.librarian.tree}"
                else "${librarians.librarian.path}/${librarians.librarian.tree}/raw";
              readonly = false;
            }
            # Card checkouts live under ~/dev, outside terminal.cwd, the only path the backend binds itself.
            # Tradeoff: these profiles can read and write every repository under ~/dev, its .git included.
            ++ lib.optional (lib.elem name (["coordinator"] ++ roles)) {
              src = dev;
              readonly = false;
            }
            ++ lib.optionals (lib.elem name (["coordinator"] ++ roles)) devBinds;
          memory_mb = 4096;
          cpu_seconds = 600;
          max_procs = 256;
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
        if delegate
        then "profile_routes"
        else "default";
      backends.profile_routes.profiles = lib.optionals delegate (map (route: {name = route;}) (roles ++ lib.optional (isLinux && name == "coordinator") "librarian"));
    };
    memory = lib.optionalAttrs (lib.elem name wikiProfiles) {provider = "hwiki";};
    mcp_servers =
      {
        host.enabled = false;
      }
      // lib.optionalAttrs isLinux {
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
  workMcp = url: {
    inherit url;
    auth = "oauth";
    trust = "full";
  };
  profiles =
    {
      coordinator = {
        description = "Plans work with the user, routes native Hermes roles.";
        config =
          lib.recursiveUpdate (profileConfig {
            name = "coordinator";
            toolsets = work ++ ["clarify" "workflow" "delegation" "cronjob"] ++ lib.optional (!isLinux) "homeassistant";
            delegate = true;
          }) {
            mcp_servers = {
              linear = workMcp "https://mcp.linear.app/mcp";
              notion = workMcp "https://mcp.notion.com/mcp";
              datadog = workMcp "https://mcp.datadoghq.eu/v1/mcp";
            };
          };
        soul = soul "coordinator";
        secrets.AGENT_GH_TOKEN = config.sops.secrets.github_token.path;
        plugin = true;
      };
      assistant = {
        description = "Reads mail and calendar and writes briefs. Incoming content never authorizes engineering work.";
        config = profileConfig {
          name = "assistant";
          toolsets = base ++ ["kanban" "cronjob" "google"];
        };
        soul = soul "assistant";
        plugin = true;
      };
    }
    // lib.mapAttrs (name: wiki: {
      description = "Curates the ${wiki.tree} wiki: turns raw sources into proposals, sends the digest and applies approved proposals.";
      config =
        lib.recursiveUpdate (profileConfig {
          inherit name;
          toolsets = ["file" "skills" "memory"];
        }) {
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
      config = profileConfig {
        inherit name;
        toolsets =
          work
          ++ lib.optionals (name == "qa") ["browser" "vision"]
          ++ lib.optional (isLinux && name == "reviewer") "security"
          # Every role may spawn plain subagents; only the reviewer routes to other profiles, whose credentials a route lends.
          ++ ["delegation"];
        rea = isLinux && lib.elem name ["programmer" "reviewer" "qa" "research"];
        security = isLinux && name == "reviewer";
        delegate = name == "reviewer";
      };
      soul = soul name;
      secrets.AGENT_GH_TOKEN = config.sops.secrets.github_token.path;
      plugin = true;
    });
  manifest = pkgs.writeText "hermes-profiles.json" (builtins.toJSON {
    plugin = "${root}/nix/plugins/hermes-workflow";
    provider =
      if isLinux
      then "${inputs.hermes-official-plugins}/claude-subscription-directsdk"
      else null;
    skins."catppuccin-mocha" = "${skin}";
    office = {
      source = toString inputs.hermes-plugin-office-3d;
      revision = inputs.hermes-plugin-office-3d.rev;
      profiles = builtins.attrNames profiles ++ lib.optionals (!isLinux) ["augusto" "livia"];
    };
    profiles = lib.mapAttrs (name: managed:
      managed
      // {
        env =
          lib.optionalAttrs ((hostModels.${name}.base_url or "") == "http://127.0.0.1:11434/v1") {OPENAI_API_KEY = "ollama";}
          // lib.optionalAttrs (!isLinux && name == "coordinator") {HASS_URL = "http://home.local:8123";}
          // lib.optionalAttrs (wikiOf ? ${name}) {
            OBSIDIAN_VAULT_PATH = wikiOf.${name}.path;
            WIKI_PATH = "${wikiOf.${name}.path}/${wikiOf.${name}.tree}";
          };
      }
      // hwikiOf name)
    profiles;
    root =
      {
        config =
          lib.recursiveUpdate (profileConfig {
            name = "default";
            # hwiki exposes its tools and recall prompt only with the memory toolset.
            toolsets = ["browser" "clarify" "cronjob" "delegation" "terminal" "web" "kanban" "todo" "skills" "session_search" "a2a" "office-3d"] ++ lib.optional (wikiOf ? default) "memory";
            delegate = true;
          }) {
            gateway.multiplex_profiles = true;
            kanban = {
              dispatch_in_gateway = true;
              dispatch_profiles = roles ++ ["coordinator"];
              max_in_progress = 1;
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
    ${lib.optionalString isLinux ''
      export CLAUDE_SUBSCRIPTION_DIRECTSDK_COMMAND=${lib.getExe pkgs.claude-code}
      export HERMES_SECURITY_OSV_SCANNER=${lib.getExe pkgs.osv-scanner}
      export NIX_REMOTE=daemon
      export DOCKER_HOST=unix://${runtimeDir}/podman/podman.sock CONTAINER_HOST=unix://${runtimeDir}/podman/podman.sock
      export PNPM_CONFIG_NPMRC_AUTH_FILE=${npmrcAuth}
      # The sandbox refuses a missing bind source; the socket appears only once Podman starts.
      mkdir -p ${runtimeDir}/podman
    ''}
    unset AGENT_JAIL_SIGNING SSH_AUTH_SOCK GPG_AGENT_INFO
    ${bootstrap}
    exec ${lib.getExe package} "$@"
  '';
in {
  home.packages =
    [
      hermes
    ]
    ++ lib.optionals isLinux [pkgs.bubblewrap pkgs.util-linux pkgs.nodejs]
    ++ [
      # Upstream's desktop runs its own 0.0.0 build, whose plugin version gate skips bubblewrap: no terminal backend, no file tools.
      # The profile path, not the store path: Desktop outlives switches and respawns the gateway, and a
      # store path would keep launching the previous generation's wrapper and environment.
      (package.hermesDesktop.override {extraEnv.HERMES_DESKTOP_HERMES = "/etc/profiles/per-user/${config.home.username}/bin/hermes";})
    ];
  herdr.programs.hermes = {
    name = "Hermes";
    icon = "icons/hermes.svg";
    tint = true;
    tile = "#1c1d21";
    color = "#ffffff";
    run = ["hermes" "-p" "coordinator"];
  };
  herdr.keys."super-s" = "terminal.open:hermes";
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
    '') (builtins.attrValues librarians));
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
    wiki-sync = {
      Unit.Description = "Audit, commit and sync the wiki vault";
      Service = {
        Type = "oneshot";
        Environment = lib.mapAttrsToList (name: value: "${name}=${value}") (syncEnv librarians.librarian);
        ExecStart = "${lib.getExe vaultSync} ${librarians.librarian.path} ${librarians.librarian.tree}";
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
  launchd.agents = lib.optionalAttrs (!isLinux) (lib.mapAttrs' (_: wiki:
    lib.nameValuePair "wiki-sync-${wiki.tree}" {
      enable = true;
      config = {
        ProgramArguments = [(lib.getExe vaultSync) wiki.path wiki.tree];
        EnvironmentVariables = syncEnv wiki;
        StartInterval = 900;
        RunAtLoad = true;
        StandardOutPath = "${homeDirectory}/Library/Logs/wiki-sync-${wiki.tree}.log";
        StandardErrorPath = "${homeDirectory}/Library/Logs/wiki-sync-${wiki.tree}.log";
      };
    })
  librarians);
  programs.claude-code.mcpServers.hermes-board = {
    command = lib.getExe pkgs.python3;
    args = ["${./mcp.py}" url];
  };
  omp.mcpServers.hermes-board = {
    type = "stdio";
    command = lib.getExe pkgs.python3;
    args = ["${./mcp.py}" url];
  };
}

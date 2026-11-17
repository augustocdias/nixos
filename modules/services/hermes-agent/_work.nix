# Shared work profiles; host-specific services and terminal backends stay separate.
{
  inputs,
  models,
  fallbacks,
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
    honchoSource = inputs.honcho;
    system = pkgs.stdenv.hostPlatform.system;
    whatsappBridge = !isLinux;
  };
  roles = ["programmer" "reviewer" "qa" "research"];
  sharedSkills = import ../../programs/agent-shared/_skills.nix {inherit lib pkgs;};
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
      poll_seconds = 15;
    })} $out/settings.json
  '';
  globalContext = let
    sections = lib.splitString "\n## " (builtins.readFile ../../programs/agent-shared/context.md);
  in
    lib.concatMapStrings (section: "\n## " + section + "\n") (builtins.filter (section:
      lib.hasPrefix "Evidence and decisions" section || lib.hasPrefix "Development skills" section)
    sections);
  style = lib.concatMapStrings builtins.readFile [
    ../../programs/agent-shared/style/caveman.md
    ../../programs/agent-shared/style/ponytail.md
  ];
  soul = name:
    pkgs.writeText "${name}-SOUL.md" (builtins.readFile ./souls/${name}.md
      + lib.optionalString (lib.elem name (roles ++ ["coordinator"])) (builtins.readFile ./souls/_role.md)
      + lib.optionalString (lib.elem name (roles ++ ["coordinator" "default"])) (builtins.readFile (
        if isLinux
        then ./souls/_linux.md
        else ./souls/_darwin.md
      ))
      + builtins.readFile ./souls/_formatting.md
      + "\n# Global rules\n"
      + globalContext
      + "\n"
      + style);
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
      deny = ["*nixos-rebuild*" "*darwin-rebuild*" "git" "git *" "*/git" "*/git *"];
    };
    terminal = {
      backend =
        if isLinux
        then "bubblewrap"
        else "local";
      degraded_mode = "fail";
      # Native kanban workers override cwd with their card's explicit workspace.
      cwd = "${dev}/.hermes-workspaces/${name}";
      env_passthrough = ["NIX_REMOTE"] ++ lib.optional (name == "reviewer") "GH_TOKEN";
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
    skills.external_dirs = ["${sharedSkills.package}" "${./skills}"];
    plugins = {
      enabled =
        ["hermes-workflow" "advanced-delegation" "office-3d"]
        ++ lib.optional isLinux "bubblewrap"
        ++ lib.optional (isLinux && security) "hermes-security"
        ++ lib.optional (isLinux && rea) "rea"
        ++ lib.optional (!isLinux && name == "coordinator") "homeassistant";
      entries = lib.optionalAttrs isLinux {
        bubblewrap.settings = {
          profile = "network";
          home_default_deny = "all";
          hide = ["/run/secrets" "${homeDirectory}/.config/sops" "${config.sops.secrets.agent_ssh_key.path}"];
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
      backends.profile_routes.profiles = lib.optionals delegate (map (name: {inherit name;}) roles);
    };
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
        description = "Plans work with the user, routes native Hermes roles and resolves board blockers.";
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
          ++ lib.optional (name == "reviewer") "delegation";
        rea = isLinux && lib.elem name ["programmer" "reviewer" "qa" "research"];
        security = isLinux && name == "reviewer";
        delegate = name == "reviewer";
      };
      soul = soul name;
      secrets = lib.optionalAttrs (name == "reviewer") {GH_TOKEN = config.sops.secrets.github_token.path;};
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
          // lib.optionalAttrs (!isLinux && name == "coordinator") {HASS_URL = "http://home.local:8123";};
      })
    profiles;
    root = {
      config =
        lib.recursiveUpdate (profileConfig {
          name = "default";
          toolsets = ["browser" "clarify" "cronjob" "delegation" "terminal" "web" "kanban" "todo" "skills" "session_search" "a2a" "office-3d"];
          delegate = true;
        }) {
          gateway.multiplex_profiles = true;
          kanban = {
            dispatch_in_gateway = true;
            dispatch_profiles = roles ++ ["coordinator"];
            max_in_progress = 1;
            auto_decompose = true;
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
    };
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
      inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.desktop
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
  programs.hermes-shepherd = {
    enable = true;
    hermesPython = "${package.hermesVenv}/bin/python3";
  };
  home.file =
    lib.listToAttrs (lib.concatMap (home:
      (map (name:
        lib.nameValuePair "${home}/plugins/${name}" {source = "${inputs.hermes-official-plugins}/${name}";})
      officialPlugins)
      ++ [
        (lib.nameValuePair "${home}/plugins/office-3d" {source = inputs.hermes-plugin-office-3d;})
      ])
    ([".hermes"] ++ map (name: ".hermes/profiles/${name}") (builtins.attrNames profiles)))
    // lib.mapAttrs' (name: image:
      lib.nameValuePair "${
        if name == "default"
        then ".hermes"
        else ".hermes/profiles/${name}"
      }/assets/avatar.png" {source = ./assets/${image};}) {
      default = "hermes.png";
      coordinator = "hermes-manager.png";
      assistant = "hermes-assistant.png";
      programmer = "hermes-programmer.png";
      reviewer = "hermes-reviewer.png";
      qa = "hermes-qa.png";
      research = "hermes-researcher.png";
    }
    // {
      ".hermes/nix/plugins/hermes-workflow".source = plugin;
      # Desktop cannot stamp its package marker into a copy of a read-only store directory.
      ".hermes/desktop-plugins/office-3d/plugin.js".source = "${inputs.hermes-plugin-office-3d}/desktop/plugin.js";
    };
  home.activation.hermes-dirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run mkdir -p ${lib.escapeShellArg root} ${lib.escapeShellArg dev}
    run chmod 0700 ${lib.escapeShellArg root}
    run ${package.hermesVenv}/bin/python -c \
      'import json, sys; from pathlib import Path; from hermes_cli.ui_preferences import write_preferences; write_preferences(json.loads(Path(sys.argv[1]).read_text()), path=Path(sys.argv[2]))' \
      ${desktopSettings} ${lib.escapeShellArg "${root}/ui-preferences.json"}
  '';
  systemd.user.services = lib.optionalAttrs isLinux {
    hermes-agent = {
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
  };
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

# laptop: a work Hermes that delegates to coding agents in Herdr, as a jailed
# Home Manager user service. Included by the `work` aspect.
{inputs, ...}: {
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (config.home) homeDirectory profileDirectory;
  root = "${homeDirectory}/.hermes";
  dev = "${homeDirectory}/dev";
  port = 8652;
  url = "http://127.0.0.1:${toString port}";
  # Live Hermes-launched agents at once.
  cap = 4;

  package = import ./_package.nix {
    inherit lib;
    hermesInput = inputs.hermes-agent;
    honchoSource = inputs.honcho;
    system = pkgs.stdenv.hostPlatform.system;
    whatsappBridge = false;
  };

  mkJail = import ../../programs/agent-jail/_mk-jail.nix {inherit inputs lib pkgs config;};
  jailed = mkJail {
    name = "hermes";
    inherit package;
    readOnlyCwd = true;
    reportActivity = false;
    # Before the signing block reads it: Hermes never holds the agent key.
    pre = c: [(c.add-runtime "unset AGENT_JAIL_SIGNING")];
    extra = c:
      with c; [
        (set-env "HERMES_HOME" root)
        (try-rw-bind root root)
        # Read-only context: this repo, and Herdr Core's config and templates for `hc templates`.
        (try-readonly (noescape "\"$HOME/nixos\""))
        (try-readonly (noescape "\"$HOME/.config/herdr-core\""))
        # Under systemd, kanban would wrap workers in `systemd-run --user --scope`,
        # which needs the user bus the jail does not have.
        (add-runtime "RUNTIME_ARGS+=(--unsetenv INVOCATION_ID)")
      ];
  };
  # The service and the CLI share one jail, rooted at ~/dev (read-only).
  hermes = pkgs.writeShellScriptBin "hermes" ''
    cd ${lib.escapeShellArg dev}
    exec ${lib.getExe jailed} "$@"
  '';

  # Read-only Gmail and Calendar token for the assistant, written by `hermes -p assistant google-login`.
  googleToken = "${root}/profiles/assistant/google_token.json";

  roles = ["programmer" "reviewer" "qa" "research"];
  harnesses = ["claude" "omp"];
  writers = ["programmer"];

  sharedSkills = import ../../programs/agent-shared/_skills.nix {inherit lib pkgs;};
  # The skills each profile may start an agent with; the card's Agents line picks the harness.
  launchSkills = {
    # setup-dev-skills writes the repo: always the user's own session.
    coordinator = lib.remove "setup-dev-skills" (builtins.attrNames sharedSkills.skills);
    programmer = ["implement" "diagnosing-bugs" "prototype"];
    reviewer = ["code-review"];
    qa = ["terminal-browser" "diagnosing-bugs"];
    research = ["research" "prototype"];
  };

  reportMcp = pkgs.writeText "hermes-report-mcp.json" (builtins.toJSON {
    mcpServers.hermes-report = {
      command = lib.getExe pkgs.python3;
      args = ["${./mcp.py}" "report" url];
    };
  });
  reportExtension = pkgs.writeText "hermes-report.ts" (builtins.replaceStrings ["@url@"] [url] (builtins.readFile ./report.ts));
  # Core runs the command with `sh -c` on the host: the harness's jail wrapper keeps the
  # agent jailed. No model and no body: the harness's own defaults apply, and the plugin
  # writes the whole first message, starting with the skill call.
  templateFiles = lib.listToAttrs (lib.concatMap (harness:
    map (signing:
      lib.nameValuePair ".config/herdr-core/templates/hermes-${harness}${lib.optionalString signing "-signing"}.md" {
        text = ''
          ---
          description: Hermes card agent on ${harness}${lib.optionalString signing ", allowed to commit and push with the agent key"}; its first message calls a skill.
          command: ${lib.optionalString signing "env AGENT_JAIL_SIGNING=1 "}${
            {
              claude = "claude --mcp-config ${reportMcp} --allowedTools mcp__hermes-report";
              omp = "omp -e ${reportExtension}";
            }
            .${
              harness
            }
          }
          ---
        '';
      }) [false true])
  harnesses);

  plugin = pkgs.runCommand "hermes-plugin-herdr-agents" {} ''
    mkdir -p $out
    cp ${./plugin/__init__.py} $out/__init__.py
    cp ${./plugin/plugin.yaml} $out/plugin.yaml
    cp ${pkgs.writeText "settings.json" (builtins.toJSON {
      inherit port cap dev roles writers;
      # Repositories outside ~/dev that cards may name; agents work there with their own write access.
      extra_repos = ["${homeDirectory}/nixos"];
      hc = "${profileDirectory}/bin/hc";
      herdr_app = "${profileDirectory}/bin/herdr-app";
      google_token = googleToken;
      poll_seconds = 15;
      protocol = builtins.readFile ./protocol.md;
      profiles =
        lib.mapAttrs (_: skills: {inherit skills;}) launchSkills
        // {
          assistant = {
            force_blocked = true;
            google = true;
          };
        };
    })} $out/settings.json
  '';

  # Global rules that apply without a shell: evidence and the development-skills workflow.
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
  soul = name: extra: pkgs.writeText "${name}-SOUL.md" (builtins.readFile ./souls/${name}.md + extra + builtins.readFile ./souls/_formatting.md + "\n# Global rules\n" + globalContext + "\n" + style);

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

  # Every configurable toolset at the pinned Hermes; each profile disables what it does not list.
  allToolsets = ["web" "browser" "terminal" "file" "code_execution" "vision" "video" "image_gen" "video_gen" "x_search" "tts" "skills" "todo" "kanban" "memory" "context_engine" "session_search" "connections" "clarify" "delegation" "cronjob" "discord" "discord_admin" "yuanbao" "computer_use"];
  luna = {
    provider = "main";
    model = "gpt-6-luna";
    reasoning_effort = "low";
  };
  # Every listed call costs more than the per-chat limit, so each one asks Allow Once or
  # Deny, whatever the trust tier, YOLO or approvals mode; unattended runs refuse.
  askEveryCall = tools: note: {
    tool_costs = lib.genAttrs tools (_: {
      credits = 2;
      inherit note;
    });
    spend_limit = 1;
    cost_unit = "approvals";
  };
  hostMcp =
    {
      command = lib.getExe pkgs.python3;
      args = ["${../../programs/agent-jail/host-mcp.py}"];
    }
    // askEveryCall ["host_exec" "host_mount" "host_journal" "host_ssh_agent"] "host access outside the jail";
  # Triage context for the coordinator. OAuth runs at runtime (`hermes -p coordinator mcp login <name>`).
  # Known write tools ask every call; `untrusted` makes any other tool without a read-only hint ask too.
  workMcp = url: writes:
    {
      inherit url;
      auth = "oauth";
      trust = "untrusted";
    }
    // askEveryCall writes "writes to a work system";
  workMcps = {
    linear = workMcp "https://mcp.linear.app/mcp" [
      "save_issue"
      "save_comment"
      "save_document"
      "save_project"
      "save_milestone"
      "save_initiative"
      "save_status_update"
      "save_release"
      "save_release_note"
      "save_issue_label"
      "save_project_label"
      "save_initiative_label"
      "save_diff_comment"
      "create_attachment"
      "create_attachment_from_upload"
      "create_issue_label"
      "create_initiative_label"
      "delete_attachment"
      "delete_comment"
      "delete_diff_comment"
      "delete_status_update"
      "update_diff"
      "merge_diff"
      "submit_diff_review"
      "resolve_diff_thread"
      "share_issue"
      "unshare_issue"
    ];
    notion = workMcp "https://mcp.notion.com/mcp" [
      "notion-create-pages"
      "notion-update-page"
      "notion-move-pages"
      "notion-duplicate-page"
      "notion-create-database"
      "notion-update-data-source"
      "notion-create-view"
      "notion-update-view"
      "notion-create-comment"
      "notion-update-comment"
      "notion-delete-comment"
      "notion-delete-pages"
      "notion-delete-databases"
      "notion-create-suggested-edit"
      "notion-resolve-suggested-edit"
      "notion-calendar-create-events"
      "notion-calendar-update-events"
      "notion-calendar-cancel-events"
    ];
    datadog = workMcp "https://mcp.datadoghq.eu/v1/mcp" [
      "create_datadog_notebook"
      "edit_datadog_notebook"
      "delete_datadog_notebook"
      "upsert_datadog_dashboard"
    ];
  };
  profileConfig = {
    model,
    toolsets,
    host ? true,
    extraMcp ? {},
  }: {
    model = {
      provider = "openai-codex";
      default = model;
    };
    agent = {
      reasoning_effort = "medium";
      disabled_toolsets = lib.subtractLists toolsets allToolsets;
    };
    auxiliary = {
      compression = luna;
      approval = luna;
      title_generation = luna;
    };
    # Legacy opt-in: kanban on every chat platform without naming platforms in Nix.
    toolsets = lib.optional (lib.elem "kanban" toolsets) "kanban";
    # Kanban worker turns use the cli list.
    platform_toolsets.cli = toolsets;
    security.allow_lazy_installs = false;
    # The classic `hermes` CLI; vim_mode does not apply to `hermes --tui`.
    display = {
      vim_mode = true;
      skin = "catppuccin-mocha";
      streaming = true;
      bell_on_prompt = true;
    };
    skills.external_dirs = [
      "${sharedSkills.package}"
      "${./skills}"
      "${../../programs/herdr/skills}"
      "${../../programs/claude-code/skills}"
    ];
    # Disabled explicitly: the bootstrap merges and never deletes, so an older `host` entry would survive.
    mcp_servers =
      {
        host =
          if host
          then hostMcp
          else {enabled = false;};
      }
      // extraMcp;
  };
  base = ["skills" "memory" "session_search"];
  profiles =
    {
      coordinator = {
        description = "Orchestrator: triages work with the user, prepares Herdr spaces, owns decomposed parent cards and judges them when their children finish. Not for implementation.";
        config =
          lib.recursiveUpdate (profileConfig {
            model = "gpt-6-astra";
            # terminal: hc and herdr-app for Herdr spaces (the user's choice). web: triage research.
            toolsets = base ++ ["kanban" "clarify" "cronjob" "agents" "terminal" "file" "web"];
            extraMcp = workMcps;
          }) {
            # Its terminal reaches the host through Herdr: every command asks the user.
            approvals.mode = "manual";
          };
        soul = soul "coordinator" "";
        plugin = true;
      };
      assistant = {
        description = "Reads the user's mail and calendar and writes briefs. Never assign engineering work here.";
        config = profileConfig {
          model = "gpt-6-luna";
          # google: the plugin's read-only Gmail and Calendar tools.
          toolsets = base ++ ["kanban" "cronjob" "google"];
          host = false;
        };
        soul = soul "assistant" "";
        plugin = true;
      };
    }
    // lib.genAttrs roles (role: {
      description =
        {
          programmer = "Implements tickets, fixes bugs and builds prototypes through a launched coding agent; requests review when done.";
          reviewer = "Reviews code changes against a ticket through a launched coding agent running code-review.";
          qa = "Runs end-to-end and manual-style checks of a reviewed change through a launched coding agent.";
          research = "Answers questions from primary sources through a launched coding agent running the research skill.";
        }
        .${
          role
        };
      config = profileConfig {
        model =
          {
            programmer = "gpt-6.1-sol";
            reviewer = "gpt-6-astra";
            qa = "gpt-6.1-sol";
            research = "gpt-6-astra";
          }
          .${
            role
          };
        toolsets = base ++ ["kanban" "agents"];
        # Roles only ever run as unattended card runs, where a host_* call can never be approved.
        # Their agents ask for host access in their own terminals instead.
        host = false;
      };
      soul = soul role (builtins.readFile ./souls/_role.md);
      plugin = true;
    });

  # Profiles link to this Home Manager path, not the store path, so the `hermes` CLI picks up a
  # rebuilt plugin at once; the running gateway keeps its loaded code until restarted.
  pluginLink = "${root}/nix/plugins/herdr-agents";
  manifest = pkgs.writeText "hermes-profiles.json" (builtins.toJSON {
    plugin = pluginLink;
    skins."catppuccin-mocha" = "${skin}";
    inherit profiles;
    # Messages no runtime route matches land here: it gets no work tools.
    root = {
      config =
        lib.recursiveUpdate (profileConfig {
          model = "gpt-6-luna";
          toolsets = ["clarify"];
          host = false;
        }) {
          # This root profile is the host gateway serving every profile. Explicit, because
          # an unset flag multiplexes only when the boot preflight passes.
          gateway.multiplex_profiles = true;
          kanban = {
            dispatch_in_gateway = true;
            # The coordinator owns decomposed root cards and judges them when their children finish.
            dispatch_profiles = roles ++ ["coordinator"];
            # Triage cards are ready work: the decomposer routes them to roles by profile description.
            # Mail never lands here; the assistant's cards are created blocked.
            auto_decompose = true;
            orchestrator_profile = "coordinator";
            default_assignee = "coordinator";
          };
          auxiliary = let
            astra = {
              provider = "main";
              model = "gpt-6-astra";
              reasoning_effort = "medium";
            };
          in {
            kanban_decomposer = astra;
            triage_specifier = astra;
          };
        };
      soul = soul "default" "";
      plugin = false;
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
    PYTHONPATH=${bootstrapLib} exec ${package.hermesVenv}/bin/python ${./_bootstrap_linux.py} ${manifest}
  '';
in {
  home.packages = [hermes];

  # The Herdr App's built-in Hermes entry, opening the coordinator. A sticky
  # `hermes profile use` would also turn the gateway unit into a named profile.
  herdr.programs.hermes = {
    name = "Hermes";
    icon = "icons/hermes.svg";
    tint = true;
    tile = "#1c1d21";
    color = "#ffffff";
    run = ["hermes" "-p" "coordinator"];
  };
  herdr.keys."super-s" = "terminal.open:hermes";
  # The board helper runs unjailed in the App's environment: no HERMES_HOME, so ~/.hermes, the jail's root.
  programs.hermes-shepherd = {
    enable = true;
    hermesPython = "${package.hermesVenv}/bin/python3";
  };
  assertions = [
    {
      assertion = lib.all (skill: sharedSkills.skills ? ${skill}) (lib.concatLists (lib.attrValues launchSkills));
      message = "hermes-agent: a launch skill is missing from agent-shared/skills";
    }
  ];
  home.file =
    templateFiles
    // {
      ".hermes/nix/plugins/herdr-agents".source = plugin;
    };

  home.activation.hermes-dirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run mkdir -p ${lib.escapeShellArg root}
    run chmod 0700 ${lib.escapeShellArg root}
    run mkdir -p ${lib.escapeShellArg dev}
  '';

  systemd.user.services.hermes-agent = {
    Unit = {
      Description = "Hermes Agent gateway (work delegator)";
      # A rebuild must not interrupt a turn; restart by hand.
      X-RestartIfChanged = false;
    };
    Service = {
      Environment = [
        "HERMES_HOME=${root}"
        "PATH=${profileDirectory}/bin:/run/current-system/sw/bin"
      ];
      WorkingDirectory = dev;
      ExecStartPre = "${bootstrap}";
      ExecStart = "${lib.getExe hermes} gateway run";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install.WantedBy = ["default.target"];
  };

  # No credentials: every card the board MCP files lands in triage.
  programs.claude-code.mcpServers.hermes-board = {
    command = lib.getExe pkgs.python3;
    args = ["${./mcp.py}" "board" url];
  };
  omp.mcpServers.hermes-board = {
    type = "stdio";
    command = lib.getExe pkgs.python3;
    args = ["${./mcp.py}" "board" url];
  };
}

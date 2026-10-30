{
  den,
  lib,
  ...
}: {
  flake-file.inputs.ponytail = {
    url = lib.mkDefault "github:DietrichGebert/ponytail";
    flake = false;
  };

  den.aspects.claude-code = {
    homeManager = {
      pkgs,
      config,
      ...
    }: let
      shared = import ../agent-shared/_lib.nix {inherit lib;};
      skills = import ../agent-shared/_skills.nix {inherit lib pkgs;};
      prompt = kind: name: fm:
        shared.withFrontmatter
        ({description = shared.description.${name};} // fm)
        "${shared.${kind}}/${name}.md";
      local = name: description: fm:
        shared.withFrontmatter ({inherit name description;} // fm) ./agents/${name}.md;

      readOnly = {disallowedTools = "Write, Edit, NotebookEdit";};

      mcp = server: tool: "mcp__plugin_hm_${server}__${tool}";

      # Unused claude.ai connectors. A server-level rule removes every tool of
      # that connector from the context. Slack and Claude_Docs stay.
      unusedConnectors = [
        "Ashby"
        "Atlassian"
        "Canva"
        "Chargebee"
        "Context7"
        "Docusign"
        "ElevenLabs"
        "Exa"
        "Facebook_Ads"
        "Figma"
        "GitHub_MCP"
        "Gmail"
        "Google_Calendar"
        "Google_Docs"
        "Google_Drive"
        "Google_Sheets"
        "Google_Slides"
        "Granola"
        "Higgsfield_AI"
        "HubSpot"
        "Intercom"
        "Leapsome"
        "Menti"
        "Microsoft_365"
        "Miro"
        "Mixpanel"
        "Personio"
        "Salesforce"
        "Swat_io"
        "TaskRay"
        "Vantage"
        "Webflow"
        "Wispr_Flow"
        "moss"
        "n8n"
        "vibiz_ai"
      ];

      # Bare tool names in deny drop the definition from the context.
      unusedTools = [
        "DesignSync"
        "NotebookEdit"
        "RemoteTrigger"
        "CronCreate"
        "CronDelete"
        "CronList"
        "ScheduleWakeup"
        "PushNotification"
        "ShareOnboardingGuide"
        "SendFeedback"
        "ReportFindings"
      ];

      perms = import ./_permissions.nix {
        baseBash = import ../agent-shared/_bash.nix {jailed = true;};
      };

      statusline = pkgs.writeShellApplication {
        name = "claude-statusline";
        runtimeInputs = [pkgs.jq pkgs.git];
        text = ''
          input=$(cat)
          dir=$(jq -r '.workspace.current_dir // .cwd // empty' <<<"$input")
          branch=""
          if [ -n "$dir" ] && b=$(git -C "$dir" --no-optional-locks branch --show-current 2>/dev/null) && [ -n "$b" ]; then
            git -C "$dir" --no-optional-locks diff --quiet HEAD 2>/dev/null || b="$b*"
            branch=$b
          fi
          jq -r --arg branch "$branch" -f ${./statusline.jq} <<<"$input"
        '';
      };

      herdrHook = "${config.programs.claude-code.configDir}/hooks/herdr-agent-state.sh";
    in {
      home.file.".claude/keybindings.json".text = builtins.toJSON {
        "$schema" = "https://www.schemastore.org/claude-code-keybindings.json";
        "$docs" = "https://code.claude.com/docs/en/keybindings";
        bindings = [
          {
            context = "Chat";
            bindings = {
              "ctrl+g" = null;
              "ctrl+e" = "chat:externalEditor";
            };
          }
        ];
      };

      programs.claude-code = {
        enable = true;
        # The jail (claude-code-jail) installs `claude`.
        package = null;

        context =
          shared.contextText
          + "\n"
          + builtins.readFile ../agent-jail/jail-context.md;

        settings = {
          autoMemoryEnabled = false;
          env = {
            DISABLE_AUTOUPDATER = "1";
            CLAUDE_CODE_ENABLE_TODO_TOOLS = "1";
          };
          skillListingMaxDescChars = 160;
          # Context budget: bundled skills and workflows are unused.
          disableBundledSkills = true;
          disableWorkflows = true;
          editorMode = "vim";
          tui = "fullscreen";
          statusLine = {
            type = "command";
            command = lib.getExe statusline;
            padding = 0;
          };
          permissions = {
            defaultMode = "auto";
            allow =
              perms.allow
              ++ map (t: mcp "context7" t) ["*"]
              ++ map (t: mcp "nixos" t) ["*"]
              ++ map (t: mcp "datadog" t) ["*"]
              ++ map (t: mcp "linear" t) ["list_*" "get_*" "search_*"]
              ++ map (t: mcp "Notion" t) ["notion-fetch" "notion-search" "notion-query-*" "notion-get-*"];
            # ask beats allow, so the host tools prompt on every call.
            ask = perms.ask ++ map (mcp "host") ["host_exec" "host_mount" "host_journal" "host_ssh_agent"];
            deny =
              perms.deny
              ++ unusedTools
              ++ map (c: "mcp__claude_ai_${c}") unusedConnectors;
          };

          hooks.SessionStart = [
            {
              matcher = "^(startup|resume|clear|compact|fork)$";
              hooks = [
                {
                  type = "command";
                  command = "bash '${herdrHook}' session";
                  timeout = 10;
                }
              ];
            }
          ];
          # rtk rewrites Bash calls (`git status` -> `rtk git status`); the
          # `rtk <pattern>` twins in agent-shared/_bash.nix keep the rules
          # matching the rewritten command.
          hooks.PreToolUse = [
            {
              matcher = "Bash";
              hooks = [
                {
                  type = "command";
                  command = "${lib.getExe pkgs.rtk} hook claude";
                }
              ];
            }
          ];
        };

        hooks."herdr-agent-state.sh" = "${pkgs.herdr.src}/src/integration/assets/claude/herdr-agent-state.sh";

        mcpServers = {
          context7 = {
            command = "npx";
            args = ["-y" "@upstash/context7-mcp"];
            env.DEFAULT_MINIMUM_TOKENS = "64000";
          };
          nixos = {
            command = "nix";
            args = ["run" "github:utensils/mcp-nixos" "--"];
          };
          host = {
            command = lib.getExe pkgs.python3;
            args = ["${../agent-jail/host-mcp.py}"];
          };
          Notion = {
            type = "http";
            url = "https://mcp.notion.com/mcp";
          };
          linear = {
            type = "http";
            url = "https://mcp.linear.app/mcp";
          };
          datadog = {
            type = "http";
            url = "https://mcp.datadoghq.eu/v1/mcp";
          };
        };

        agents = {
          test-writer = prompt "agents" "test-writer" {name = "test-writer";};
          troubleshoot = local "troubleshoot" "Investigates production issues and incidents using Datadog (logs, traces, metrics, RUM, monitors, incidents). Use for \"why is X slow/erroring\", incident triage, latency/error spikes, log/trace analysis, or metric investigation." readOnly;
          tickets = local "tickets" "Researches Linear/Notion identifiers and context through read-only tools. Returns exact mutation proposals in the parent's supplied schema; the parent handles approval and execution." readOnly;
        };

        commands = {
          commit = prompt "commands" "commit" {};
        };

        skills =
          skills.skills
          // {
            datadog-queries = ./skills/datadog-queries;
          };
      };
    };
  };
}

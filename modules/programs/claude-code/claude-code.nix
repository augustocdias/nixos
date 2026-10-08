{
  den,
  inputs,
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
      prompt = kind: name: fm:
        shared.withFrontmatter
        ({description = shared.description.${name};} // fm)
        "${shared.${kind}}/${name}.md";
      local = name: description: fm:
        shared.withFrontmatter ({inherit name description;} // fm) ./agents/${name}.md;

      readOnly = {disallowedTools = "Write, Edit, NotebookEdit";};

      mcp = server: tool: "mcp__plugin_hm_${server}__${tool}";

      perms = import ./_permissions.nix {
        baseBash = (import ../opencode/_permissions.nix {jailed = true;}).baseBash;
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
          builtins.readFile shared.context
          + "\n"
          + builtins.readFile ../agent-jail/jail-context.md;

        settings = {
          env.DISABLE_AUTOUPDATER = "1";
          editorMode = "vim";
          tui = "fullscreen";
          statusLine = {
            type = "command";
            command = lib.getExe statusline;
            padding = 0;
          };
          permissions = {
            defaultMode = "plan";
            allow =
              perms.allow
              ++ map (t: mcp "context7" t) ["*"]
              ++ map (t: mcp "nixos" t) ["*"]
              ++ map (t: mcp "datadog" t) ["*"]
              ++ map (t: mcp "linear" t) ["list_*" "get_*" "search_*"]
              ++ map (t: mcp "Notion" t) ["notion-fetch" "notion-search" "notion-query-*" "notion-get-*"];
            # ask beats allow, so the host tools prompt on every call.
            ask = perms.ask ++ map (mcp "host") ["host_exec" "host_mount" "host_journal"];
            inherit (perms) deny;
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
            url = "https://mcp.datadoghq.eu/api/unstable/mcp-server/mcp";
          };
        };

        agents = {
          reviewer = prompt "agents" "reviewer" ({name = "reviewer";} // readOnly);
          test-writer = prompt "agents" "test-writer" {name = "test-writer";};
          troubleshoot = local "troubleshoot" "Investigates production issues and incidents using Datadog (logs, traces, metrics, RUM, monitors, incidents). Use for \"why is X slow/erroring\", incident triage, latency/error spikes, log/trace analysis, or metric investigation." readOnly;
          tickets = local "tickets" "Manages Linear issues and Notion docs — triage, spec writing, status updates, ticket creation, and cross-referencing docs. Writes are approval-gated. Use for ticket workflow, writing/updating specs, or pulling context out of Notion/Linear." readOnly;
        };

        commands = {
          commit = prompt "commands" "commit" {};
          pr = prompt "commands" "pr" {};
          review = prompt "commands" "review" {
            context = "fork";
            agent = "reviewer";
          };
        };

        skills = {
          git-conventions = "${shared.skills}/git-conventions";
          datadog-queries = ./skills/datadog-queries;
        };

        plugins = {
          caveman = inputs.caveman;
          ponytail = inputs.ponytail;
        };
      };
    };
  };
}

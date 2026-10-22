{den, ...}: {
  den.aspects.herdr = {
    homeManager = {
      config,
      pkgs,
      lib,
      ...
    }: let
      herdrSkill =
        pkgs.runCommand "herdr-skill.md" {
          nativeBuildInputs = [pkgs.herdr];
        } ''
          herdr --skill > $out
        '';

      mkFish = name: file: extra: let
        substitutions =
          {
            "@herdr@" = lib.getExe pkgs.herdr;
            "@jq@" = lib.getExe pkgs.jq;
            "@sleep@" = lib.getExe' pkgs.coreutils "sleep";
            "@git@" = lib.getExe pkgs.git;
            "@direnv@" = lib.getExe pkgs.direnv;
          }
          // extra;
      in
        pkgs.writers.writeFishBin name (
          builtins.replaceStrings
          (builtins.attrNames substitutions)
          (builtins.attrValues substitutions)
          (builtins.readFile file)
        );

      nav = mkFish "herdr-nav" ./nav.fish {};
      resize = mkFish "herdr-resize" ./resize.fish {};
      # The agent the default layout starts next to nvim.
      workspace = mkFish "herdr-workspace" ./workspace.fish {"@agent@" = "omp";};
      worktree = mkFish "herdr-worktree" ./worktree.fish {
        "@workspace@" = "${workspace}/bin/herdr-workspace";
      };
      pluginsSync = mkFish "herdr-plugins-sync" ./plugins-sync.fish {};

      plugins = [];

      pluginSkills = lib.listToAttrs (lib.concatMap (
          plugin:
            lib.optionals (plugin.skills != null) (
              map
              (name:
                lib.nameValuePair ".omp/agent/skills/${name}/SKILL.md" {
                  source = "${plugin.skills}/${name}/SKILL.md";
                })
              (builtins.attrNames (builtins.readDir plugin.skills))
            )
        )
        plugins);

      shellKey = key: command: description: {
        inherit key command description;
        type = "shell";
      };

      # Popups own the terminal, so they are the only custom command type that
      # can prompt for input.
      popupKey = key: command: description: {
        inherit key command description;
        type = "popup";
        width = "60%";
        height = "30%";
      };
    in {
      home.packages = [workspace worktree];

      # No-op unless the claude-code aspect enables the module.
      programs.claude-code = {
        skills.herdr = herdrSkill;

        # Ours, next to herdr's SessionStart hook: metadata only, feeding the Agents sidebar.
        hooks."herdr-activity.py" = ./claude-activity.py;
        settings.hooks = let
          hook = matcher: [
            ({
                hooks = [
                  {
                    type = "command";
                    command = "${lib.getExe pkgs.python3} '${config.programs.claude-code.configDir}/hooks/herdr-activity.py'";
                    timeout = 5;
                  }
                ];
              }
              // lib.optionalAttrs (matcher != null) {inherit matcher;})
          ];
        in {
          SessionStart = hook null;
          UserPromptSubmit = hook null;
          Stop = hook null;
          PreToolUse = hook "^(Agent|Task)$";
          PostToolUse = hook "^(TaskCreate|TaskUpdate|TodoWrite)$";
          SubagentStart = hook null;
          SubagentStop = hook null;
          Notification = hook "^idle_prompt$";
          SessionEnd = hook null;
        };
      };

      home.file =
        {
          # herdr's omp integration: lifecycle state, session identity and
          # resume. Same file `herdr integration install omp` writes, from the
          # same source revision as the binary, so status stays clean.
          ".omp/agent/extensions/herdr-omp-agent-state.ts".source = "${pkgs.herdr.src}/src/integration/assets/omp/herdr-agent-state.ts";
          # Ours, next to herdr's: metadata only, feeding the Agents sidebar.
          ".omp/agent/extensions/herdr-activity.ts".source = ./omp-activity.ts;
          ".omp/agent/skills/herdr/SKILL.md".source = herdrSkill;
        }
        // pluginSkills;

      home.activation.herdr-plugins = lib.hm.dag.entryAfter ["writeBoundary"] ''
        ${pluginsSync}/bin/herdr-plugins-sync ${lib.escapeShellArgs plugins} \
          || echo "herdr: plugin sync failed" >&2
      '';

      systemd.user.services.herdr = {
        Unit = {
          Description = "herdr terminal workspace manager";
          PartOf = ["graphical-session.target"];
          After = ["graphical-session.target"];
          X-SwitchMethod = "keep-old";
        };

        Service = {
          Type = "simple";
          ExecStart = "${lib.getExe pkgs.herdr} server";
          ExecStop = "${lib.getExe pkgs.herdr} server stop";
          Restart = "on-failure";
          RestartSec = 2;
          OOMPolicy = "continue";
          TimeoutStopSec = 30;
        };
        Install.WantedBy = ["graphical-session.target"];
      };

      programs.herdr = {
        enable = true;

        settings = {
          onboarding = false;
          update.version_check = false;

          theme.name = "catppuccin";

          session.resume_agents_on_restore = true;

          worktrees.directory = "~/dev/worktrees";

          experimental = {
            pane_history = true;
            kitty_graphics = true;
          };

          ui = {
            copy_on_select = true;
            sound.enabled = false;
            pane_gaps = false;
            sidebar_collapsed_mode = "compact";
            sidebar_width = 36;
            sidebar_max_width = 36;
            agent_panel_sort = "priority";
            toast.delivery = "system";
            right_click_passthrough_modifier = "ctrl";
            pane_scrollbars = false;
            hide_tab_bar_when_single_tab = true;

            # Tokens come from omp-activity.ts / claude-activity.py. Rows and tokens with no
            # value disappear, so an idle agent collapses to the first line.
            sidebar.agents.rows = [
              [
                "state_icon"
                {
                  token = "workspace";
                  bold = true;
                }
                "$agent"
              ]
              [
                {
                  token = "$title";
                  dim = true;
                }
              ]
              [
                {
                  token = "$todo";
                  fg = "#6f8f6b";
                  dim = true;
                }
              ]
              [
                {
                  token = "$sub1";
                  fg = "#6c7086";
                  dim = true;
                }
              ]
              [
                {
                  token = "$sub2";
                  fg = "#6c7086";
                  dim = true;
                }
              ]
              [
                {
                  token = "$sub3";
                  fg = "#6c7086";
                  dim = true;
                }
              ]
              [
                {
                  token = "$submore";
                  fg = "#6c7086";
                  dim = true;
                }
              ]
            ];
          };

          keys = {
            prefix = "ctrl+g";

            zoom = ["prefix+z" "prefix+f" "alt+m"];
            new_tab = ["prefix+c" "prefix+t"];
            next_tab = ["prefix+n" "alt+]"];
            previous_tab = ["prefix+p" "alt+["];
            copy_mode = ["prefix+[" "prefix+s"];
            resize_mode = ["prefix+r" "alt+r"];
            goto = ["prefix+g" "alt+w"];
            detach = ["prefix+q" "alt+d"];
            settings = "prefix+shift+s";
            toggle_sidebar = ["prefix+b" "ctrl+alt+b"];

            # herdr leaves these unbound; `""` is how its own default config
            # spells "unset", which is what hands prefix+shift+g to the
            # worktree popup below.
            new_worktree = "";
            open_worktree = "prefix+alt+g";
            remove_worktree = "prefix+ctrl+d";
            previous_workspace = "prefix+ctrl+p";
            next_workspace = "prefix+ctrl+n";
            previous_agent = "prefix+shift+a";
            next_agent = "prefix+a";
            focus_agent = "prefix+alt+1..9";
            switch_workspace = "prefix+shift+1..9";
            last_pane = "prefix+backtick";

            navigate_workspace_up = "shift+k";
            navigate_workspace_down = "shift+j";

            command = [
              (shellKey "ctrl+h" "${nav}/bin/herdr-nav left" "focus pane left (vim aware)")
              (shellKey "ctrl+j" "${nav}/bin/herdr-nav down" "focus pane down (vim aware)")
              (shellKey "ctrl+k" "${nav}/bin/herdr-nav up" "focus pane up (vim aware)")
              (shellKey "ctrl+l" "${nav}/bin/herdr-nav right" "focus pane right (vim aware)")
              (shellKey "ctrl+alt+h" "${resize}/bin/herdr-resize left" "resize pane left")
              (shellKey "ctrl+alt+j" "${resize}/bin/herdr-resize down" "resize pane down")
              (shellKey "ctrl+alt+k" "${resize}/bin/herdr-resize up" "resize pane up")
              (shellKey "ctrl+alt+l" "${resize}/bin/herdr-resize right" "resize pane right")
              (shellKey "prefix+shift+l" "${workspace}/bin/herdr-workspace" "open workspace here")
              (popupKey "prefix+shift+g" "${worktree}/bin/herdr-worktree" "new worktree")
            ];
          };
        };
      };
    };
  };
}

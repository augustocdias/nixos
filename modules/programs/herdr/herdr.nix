{
  den,
  inputs,
  ...
}: {
  flake-file.inputs.herdr-plugin-browser = {
    url = "github:ogulcancelik/herdr-browser";
    flake = false;
  };

  den.aspects.herdr = {
    homeManager = {
      pkgs,
      lib,
      ...
    }: let
      inherit (import ./_plugins.nix {inherit pkgs lib;}) mkHerdrPlugin;

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
      workspace = mkFish "herdr-workspace" ./workspace.fish {};
      worktree = mkFish "herdr-worktree" ./worktree.fish {
        "@workspace@" = "${workspace}/bin/herdr-workspace";
      };
      pluginsSync = mkFish "herdr-plugins-sync" ./plugins-sync.fish {};

      plugins = lib.optionals (pkgs.stdenv.hostPlatform.isLinux && inputs ? herdr-plugin-browser) [
        # Drives a headless Chromium in a pane over CDP. It resolves the
        # browser by PATH name and renders through kitty graphics.
        (mkHerdrPlugin {
          src = inputs.herdr-plugin-browser;
          runtimeDeps = [pkgs.bun pkgs.ungoogled-chromium];
        })
      ];

      pluginSkills = lib.listToAttrs (lib.concatMap (
          plugin:
            lib.optionals (plugin.skills != null) (
              map
              (name:
                lib.nameValuePair "opencode/skills/${name}/SKILL.md" {
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

      home.activation.herdr-plugins = lib.hm.dag.entryAfter ["writeBoundary"] ''
        ${pluginsSync}/bin/herdr-plugins-sync ${lib.escapeShellArgs plugins} \
          || echo "herdr: plugin sync failed" >&2
      '';

      xdg.configFile =
        {
          # herdr's own opencode integration and agent skill, taken from the
          # same source revision as the binary instead of `herdr integration
          # install`, which would write them imperatively.
          "opencode/plugins/herdr-agent-state.js".source = "${pkgs.herdr.src}/src/integration/assets/opencode/herdr-agent-state.js";
          "opencode/skills/herdr/SKILL.md".source = "${pkgs.herdr.src}/SKILL.md";

          # Ours, next to herdr's: metadata only, feeding the Agents sidebar.
          "opencode/plugins/herdr-activity.js".source = ./opencode-activity.js;
        }
        // pluginSkills;

      programs.herdr = {
        enable = true;

        settings = {
          onboarding = false;

          theme.name = "catppuccin";

          session.resume_agents_on_restore = true;

          # Only used by repos that do not keep their worktrees as siblings
          # inside a repo folder; `git wa` handles the ones that do.
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
            toast = {
              delivery = "herdr";
              herdr.position = "top-right";
            };

            # Tokens come from opencode-activity.js. Rows and tokens with no
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

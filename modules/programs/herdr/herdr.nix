{
  den,
  inputs,
  lib,
  ...
}: {
  # Keep the input's nixpkgs; local patches rebuild only herdr-app.
  flake-file.inputs.llm-agents.url = lib.mkDefault "github:numtide/llm-agents.nix";
  flake-file.inputs.herdr-navigation.url = "github:augustocdias/herdr-navigation";
  flake-file.inputs.herdr-hermes-shepherd.url = "github:augustocdias/herdr-hermes-shepherd";
  flake-file.inputs.herdr-tmux-prefix = {
    url = "github:herdrdev/herdr-layout-examples";
    flake = false;
  };

  den.aspects.herdr = {
    homeManager = {
      config,
      pkgs,
      lib,
      ...
    }: let
      shepherd = config.programs.hermes-shepherd.enable;
      # Shepherd's coordinator panel, a sibling of the Files/Changes column in work-body.
      shepherdPanel = builtins.toJSON {
        id = "shepherd";
        type = "column";
        hidden = true;
        size.px = 460;
        min = 280;
        max = 1100;
        children = [
          {
            id = "shepherd-bar";
            type = "block";
            size.px = 36;
            content = {
              mod = "hermes-shepherd";
              props.panel = true;
            };
          }
          {
            id = "shepherd-terminal";
            type = "block";
            content.terminal = "hermes-shepherd";
          }
        ];
      };
      herdrCore = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr-core;
      herdrApp = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr-app.overrideAttrs (old: {
        patches = (old.patches or []) ++ [./vim-navigation.patch];
        postPatch =
          (old.postPatch or "")
          + ''
            # Key shorthand must wrap a program name in argv, not pass a string.
            substituteInPlace src/commands.rs \
              --replace-fail '(None, Some(a)) => json!({ a.name: value }),' \
              '(None, Some(a)) if a.name == "argv" => json!({ a.name: [value] }),
                    (None, Some(a)) => json!({ a.name: value }),'
            # The control socket can answer before Core restores the saved spaces.
            substituteInPlace src/window.rs \
              --replace-fail '"layout": self.layout_name,' \
              '"layout": self.layout_name,
                            "local_layout_ready": self.documents.get("").is_some_and(|s| s.available),'
            substituteInPlace defaults/layouts/main.json \
              --replace-fail '"mod": "agents"' '"mod": "agents-enriched"' \
              --replace-fail '"mod": "tabs"' '"mod": "tabs-enriched"' \
              --replace-fail '"mod": "spaces"' '"mod": "spaces-enriched"'
            ${lib.optionalString shepherd ''
              substituteInPlace defaults/layouts/main.json \
                --replace-fail ${lib.escapeShellArg "              ]\n            }\n          ]\n        },\n        {\n          \"id\": \"status\","} \
                ${lib.escapeShellArg "              ]\n            },\n${shepherdPanel}\n          ]\n        },\n        {\n          \"id\": \"status\","}
            ''}
            substituteInPlace defaults/AGENTS.md \
              --replace-fail '<!-- Written by the Herdr app on every start. Edits here are overwritten. -->' \
              ${lib.escapeShellArg ''
              <!-- Written by the Herdr app on every start. Edits here are overwritten. -->

              ## Nix-managed installation and configuration

              Persistent changes belong in the Nix configuration repository, in
              `modules/programs/herdr/herdr.nix` and its referenced sources.
              Define every added package, dependency, mod, layout, theme, setting,
              and keybinding in Nix before installing or applying it. Track third-party
              sources in flake.lock and review their code and permissions before adding them.

              The file-editing and installation examples below describe formats and
              capabilities. Apply them through Nix, not by editing managed files or
              running imperative installers. Keep runtime session and window state
              app-owned. Preserve Nix-managed symlinks; emergency reset may move the
              keys link, which requires a rebuild to restore.

              Build and activate the system configuration before calling a persistent
              change installed. Follow the repository's `docs/system.md` rebuild
              workflow. On Linux, use the approved host route or have the user run
              `sudo nixos-rebuild switch --flake .` from the repository. Never use
              Herdr Core to bypass activation approvals. Report pending activation
              or relaunch as pending, not complete.

              This guide is embedded in the Nix package and regenerated at startup.
              Update its package patch to change this policy.
            ''}
          '';
      });
      appDefaultKeys =
        lib.recursiveUpdate
        (builtins.fromJSON (builtins.readFile "${herdrApp.src}/defaults/keys${lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ".macos"}.json"))
        inputs.herdr-navigation.lib.keys;
      prefixKey =
        if pkgs.stdenv.hostPlatform.isLinux
        then "super-h"
        else "ctrl-b";
      tmuxPrefix = pkgs.runCommand "herdr-tmux-prefix" {} ''
        mkdir -p $out
        cp ${inputs.herdr-tmux-prefix}/tmux-prefix/mods/tmux-prefix/{main.js,mod.json} $out/
        chmod u+w $out/main.js
        ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
          substituteInPlace $out/main.js \
            --replace-fail 'this.sendPrefix(cx);' 'this.dismiss();' \
            --replace-fail ${lib.escapeShellArg "  sendPrefix(cx) {\n    this.send(\"ctrl+b\", cx);\n  }\n"} "" \
            --replace-fail 'if (m.control && e.key === "b") return this.dismiss();' \
              'if (m.platform && e.key === "h") return this.dismiss();' \
            --replace-fail 'Ctrl+B' 'Super+H' \
            --replace-fail 'Esc cancel · ^B send prefix' 'Esc / Super+H cancel'
        ''}
      '';
      enrichedAgents = pkgs.runCommand "herdr-agents-enriched" {} ''
        mkdir -p $out
        cp ${herdrApp.src}/defaults/mods/agents/{main.js,mod.json} $out/
        cp ${./activity.js} $out/activity.js
        chmod u+w $out/{main,activity}.js
        # App rejects relative imports through store symlinks; keep the mod in one file.
        substituteInPlace $out/activity.js \
          --replace-fail 'import { div } from "gpui-kit";' "" \
          --replace-fail 'import { v_flex } from "gpui-base";' "" \
          --replace-fail 'export function ' 'function '
        cat $out/activity.js >> $out/main.js
        rm $out/activity.js
        substituteInPlace $out/main.js \
          --replace-fail 'const all = terminals();' \
            'const all = terminals();
            const metadata = new Map(all.map(t => [t.address, activity(t)]));' \
          --replace-fail 'return [r, ...subs.map' \
            'return [r, ...(collapsed ? [] : activityRows(metadata.get(a.address), a.address, t)), ...subs.map' \
          --replace-fail '.when(Boolean(machine), el =>' \
            '.when(Boolean(metadata.get(a.address)?.agent), el => el.child(div().max_w(110).truncate().text_size(10.5).text_color(t.muted).tooltip(metadata.get(a.address).agent).child(metadata.get(a.address).agent)))
                .when(Boolean(machine), el =>' \
          --replace-fail 'mod: "agents", kind: "popup"' 'mod: "agents-enriched", kind: "popup"'
      '';

      mkFish = name: file: extra: let
        substitutions =
          {
            "@app@" = lib.getExe herdrApp;
            "@jq@" = lib.getExe pkgs.jq;
            "@sleep@" = lib.getExe' pkgs.coreutils "sleep";
            "@seq@" = lib.getExe' pkgs.coreutils "seq";
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

      workspace = mkFish "herdr-workspace" ./workspace.fish {};
      worktree = mkFish "herdr-worktree" ./worktree.fish {
        "@workspace@" = "${workspace}/bin/herdr-workspace";
      };
    in {
      imports = [
        inputs.herdr-navigation.homeManagerModules.default
        inputs.herdr-hermes-shepherd.homeManagerModules.default
      ];

      options.herdr = {
        programs = lib.mkOption {
          type = lib.types.attrsOf (pkgs.formats.json {}).type;
          default = {};
          description = "Extra or overridden entries for herdr-app/programs.json, merged over the App's defaults.";
        };
        keys = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          description = "Extra global App keybindings, e.g. a key that opens one of `herdr.programs`.";
        };
      };

      config = {
        home.packages = [workspace worktree herdrApp herdrCore];

        # The label "default" names Hermes's default board, so the tab shows it without a fallback hint.
        programs.herdr-navigation.pinnedTabs = lib.mkIf shepherd [
          {
            label = "default";
            mod = "hermes-shepherd";
          }
        ];
        herdr.keys = lib.mkIf shepherd {"ctrl-shift-y" = "layout.toggle:shepherd";};

        xdg.configFile = {
          "herdr-app/settings.json".text = builtins.toJSON {
            zoom = 1;
            sounds.enabled = true;
            minimum_contrast = 1;
            appearance = "dark";
            font = "MonaspiceNe Nerd Font";
            font_size = 10;
            ui_font = "MonaspiceNe Nerd Font";
            telemetry = false;
            theme = "catppuccin";
          };
          "herdr-app/keys.json".text = builtins.toJSON (lib.recursiveUpdate appDefaultKeys {
            global =
              {
                "alt-m" = "pane.zoom";
                "alt-]" = "tab.next";
                "alt-[" = "tab.prev";
                "ctrl-shift-r" = "tab.rename";
                ${prefixKey} = "mod.open:tmux-prefix";
              }
              // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
                "super-t" = "terminal.open";
                "super--" = "pane.split:down";
                "super-\\" = "pane.split:right";
                "super-o" = "terminal.open:omp";
                "super-c" = "terminal.open:claude";
              }
              // config.herdr.keys;
            "layout:main"."ctrl-alt-b" = "layout.toggle:sidebar";
            terminal = {
              ${prefixKey} = "mod.open:tmux-prefix";
              "ctrl-h" = "pane.navigate:left";
              "ctrl-j" = "pane.navigate:down";
              "ctrl-k" = "pane.navigate:up";
              "ctrl-l" = "pane.navigate:right";
            };
            "mod:tmux-prefix".${prefixKey} =
              if pkgs.stdenv.hostPlatform.isLinux
              then "tmux-prefix.dismiss"
              else "tmux-prefix.send-prefix";
          });
          "herdr-app/mods/tmux-prefix/main.js".source = "${tmuxPrefix}/main.js";
          "herdr-app/mods/tmux-prefix/mod.json".source = "${tmuxPrefix}/mod.json";
          "herdr-app/mods/agents-enriched/main.js".source = "${enrichedAgents}/main.js";
          "herdr-app/mods/agents-enriched/mod.json".source = "${enrichedAgents}/mod.json";
          "herdr-app/programs.json".text = builtins.toJSON {
            programs =
              {
                omp = {
                  name = "OMP";
                  icon = "icons/pi.svg";
                  tint = true;
                  run = ["omp"];
                };
              }
              // config.herdr.programs;
          };
          "herdr-app/themes/catppuccin.json".text = builtins.toJSON {
            background = "#1e1e2e";
            foreground = "#cdd6f4";
            selection = "#45475a";
            cursor = "#f5e0dc";
            ansi = [
              "#45475a"
              "#f38ba8"
              "#a6e3a1"
              "#f9e2af"
              "#89b4fa"
              "#f5c2e7"
              "#94e2d5"
              "#bac2de"
              "#585b70"
              "#f38ba8"
              "#a6e3a1"
              "#f9e2af"
              "#89b4fa"
              "#f5c2e7"
              "#94e2d5"
              "#a6adc8"
            ];
          };
        };

        # No-op unless the claude-code aspect enables the module.
        programs.claude-code = {
          skills.herdr-app = ./skills/herdr-app;
          skills.herdr-core = ./skills/herdr-core;

          # Display metadata is separate from the agents' native OSC lifecycle reports.
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

        home.file = {
          ".omp/agent/extensions/herdr-activity.ts".source = ./omp-activity.ts;
          ".omp/agent/skills/herdr-app" = {
            source = ./skills/herdr-app;
            recursive = true;
          };
          ".omp/agent/skills/herdr-core" = {
            source = ./skills/herdr-core;
            recursive = true;
          };
        };

        home.activation.herdr-sidebar-state = lib.hm.dag.entryAfter ["writeBoundary"] ''
          old=${lib.escapeShellArg "${config.xdg.configHome}/herdr-app/data/agents"}
          new=${lib.escapeShellArg "${config.xdg.configHome}/herdr-app/data/agents-enriched"}
          if [ -d "$old" ] && [ ! -e "$new" ]; then
            ${lib.getExe' pkgs.coreutils "cp"} -R -- "$old" "$new"
          fi
        '';
      };
    };
  };
}

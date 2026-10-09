{
  den,
  inputs,
  lib,
  ...
}: {
  flake-file.inputs.caveman = {
    url = lib.mkDefault "github:JuliusBrussee/caveman";
    flake = false;
  };

  den.aspects.opencode = {
    homeManager = {
      pkgs,
      lib,
      config,
      ...
    }: let
      # The bwrap jail is Linux-only, so Darwin keeps the strict allowlist as
      # its only boundary.
      perms = import ./_permissions.nix {
        jailed = pkgs.stdenv.hostPlatform.isLinux;
      };

      shared = import ../agent-shared/_lib.nix {inherit lib;};
      prompt = kind: name: fm:
        pkgs.writeText "${name}.md" (shared.withFrontmatter
          ({description = shared.description.${name};} // fm)
          "${shared.${kind}}/${name}.md");

      # --- Caveman native plugin (JuliusBrussee/caveman) -----------------
      # Reimplements the opencode-specific parts of installer/install.js in Nix so
      # the deploy is pure and does not fight the Nix-generated opencode.json.
      #
      # What the upstream installer does for --only opencode:
      #   1. Plugin files  → ~/.config/opencode/plugins/caveman/
      #      (plugin.js, package.json, caveman-config.cjs, caveman-parse.cjs)
      #   2. Commands      → ~/.config/opencode/commands/
      #   3. Agents        → ~/.config/opencode/agents/   (frontmatter transformed)
      #   4. Skills        → ~/.config/opencode/skills/
      #   5. AGENTS.md     → fenced block appended (skipped — plugin hook covers it)
      #   6. opencode.json → plugin entry appended (handled by settings.plugin)
      #
      # To detect upstream structural changes, we hash the installer's
      # opencode-relevant code at build time. If the hash drifts after
      # `nix flake update caveman`, the build fails with an explicit message.

      caveman = inputs.caveman;
      cavemanInstallerHash = "2732df386d7be86313177e388dd5eebb5a8ad51d2af938ee074f76838c5aa2ea";

      cavemanInstallerCheck = pkgs.runCommand "caveman-installer-check" {} ''
        {
          grep '^const OPENCODE_' ${caveman}/installer/install.js
          # Whole function body: a /start/,/end/ range would stop on the start
          # line itself, since it also matches the end pattern.
          awk '/^function installOpencode\(/{f=1; print; next}
               f && /^function [a-zA-Z]/{exit} f' ${caveman}/installer/install.js
          cat ${caveman}/installer/lib/opencode-agent.js
        } | sha256sum | cut -d' ' -f1 > $out

        actual=$(cat $out)
        if [ "$actual" != "${cavemanInstallerHash}" ]; then
          echo ""
          echo "ERROR: caveman's opencode installer has changed."
          echo "  expected: ${cavemanInstallerHash}"
          echo "  got:      $actual"
          echo ""
          echo "Review the installOpencode function in installer/install.js and"
          echo "installer/lib/opencode-agent.js, update the Nix reimplementation"
          echo "in opencode.nix, then set cavemanInstallerHash to the new value."
          exit 1
        fi
      '';

      # Transform agent frontmatter: strip tools: arrays and provider-less
      # model: values (e.g. "model: haiku" → dropped), and force
      # mode: subagent so cavecrew agents are invoked via Task rather
      # than showing in the agent picker alongside plan/build/pair.
      # Mirrors installer/lib/opencode-agent.js transformOpencodeAgentFrontmatter()
      # with { subagent: true }.
      cavemanAgents =
        pkgs.runCommand "caveman-agents" {
          # Force a build-time dependency on the installer check.
          inherit cavemanInstallerCheck;
        } ''
          mkdir -p $out
          for f in cavecrew-investigator.md cavecrew-builder.md cavecrew-reviewer.md; do
            ${pkgs.gawk}/bin/awk '
              BEGIN { in_fm = 0; dropping = 0 }
              /^---$/ && !in_fm { in_fm = 1; print; next }
              /^---$/ && in_fm  {
                # Inject mode: subagent before closing the frontmatter
                print "mode: subagent"
                in_fm = 0; print; next
              }
              in_fm && dropping && /^[^ \t]/ { dropping = 0 }
              in_fm && dropping { next }
              in_fm && /^tools[ \t]*:/ { dropping = 1; next }
              in_fm && /^mode[ \t]*:/ { next }
              in_fm && /^model[ \t]*:[ \t]*(.*)$/ {
                # Drop if value has no slash (provider-less)
                split($0, parts, /[ \t]*:[ \t]*/);
                val = parts[2];
                gsub(/[ \t]*#.*$/, "", val);  # strip YAML comment
                gsub(/^["'"'"']|["'"'"']$/, "", val);  # strip quotes
                if (val != "" && index(val, "/") == 0) next;
              }
              { print }
            ' ${caveman}/agents/"$f" > $out/"$f"
          done
        '';

      cavemanSkillDirs = [
        "caveman"
        "ultracave"
        "megacave"
        "caveman-commit"
        "caveman-review"
        "caveman-help"
        "caveman-stats"
        "caveman-compress"
        "cavecrew"
      ];

      cavemanCommandFiles = [
        "caveman.md"
        "ultracave.md"
        "megacave.md"
        "caveman-commit.md"
        "caveman-review.md"
        "caveman-compress.md"
        "caveman-stats.md"
        "caveman-help.md"
      ];
    in {
      # FIXME: xdg.configFile creates symlinks into /nix/store which breaks Bun's
      # module resolution for @opencode-ai/plugin (it resolves relative to the real
      # path, not the symlink). We copy the files instead until this is fixed upstream.
      # https://github.com/anomalyco/opencode/issues/5914
      home.activation.opencode-tools = lib.hm.dag.entryAfter ["writeBoundary"] ''
        mkdir -p $HOME/.config/opencode/tools
        cp -f ${./tools/date.ts} $HOME/.config/opencode/tools/date.ts
        cp -f ${./tools/gh.ts} $HOME/.config/opencode/tools/gh.ts
        cp -f ${./tools/google_calendar.ts} $HOME/.config/opencode/tools/google_calendar.ts
        cp -f ${./tools/host.ts} $HOME/.config/opencode/tools/host.ts
        printf '%s' ${import ./_sync.nix} > $HOME/.config/opencode/.sync-id

        # Caveman native plugin — same Bun symlink issue as the tools above,
        # so plugin files are copied. The .js → .cjs rename is required
        # because the plugin dir has "type": "module" in its package.json.
        mkdir -p $HOME/.config/opencode/plugins/caveman
        cp -f ${caveman}/src/plugins/opencode/plugin.js \
          $HOME/.config/opencode/plugins/caveman/plugin.js
        cp -f ${caveman}/src/plugins/opencode/package.json \
          $HOME/.config/opencode/plugins/caveman/package.json
        cp -f ${caveman}/src/hooks/caveman-config.js \
          $HOME/.config/opencode/plugins/caveman/caveman-config.cjs
        cp -f ${caveman}/src/hooks/caveman-parse.js \
          $HOME/.config/opencode/plugins/caveman/caveman-parse.cjs

        # Caveman agents — frontmatter-transformed at build time.
        cp -f ${cavemanAgents}/cavecrew-investigator.md \
          $HOME/.config/opencode/agent/cavecrew-investigator.md
        cp -f ${cavemanAgents}/cavecrew-builder.md \
          $HOME/.config/opencode/agent/cavecrew-builder.md
        cp -f ${cavemanAgents}/cavecrew-reviewer.md \
          $HOME/.config/opencode/agent/cavecrew-reviewer.md
      '';

      xdg.configFile =
        {
          # herdr's integration check reads tui.jsonc (hardcoded, no fallback
          # to tui.json). Symlink the HM-generated file under both names so
          # opencode reads it and herdr's `tui_plugin_is_configured` finds it.
          "opencode/tui.jsonc".source =
            config.xdg.configFile."opencode/tui.json".source;

          "opencode/agent/reviewer.md".source = prompt "agents" "reviewer" {mode = "subagent";};
          "opencode/agent/test-writer.md".source = prompt "agents" "test-writer" {mode = "subagent";};
          "opencode/command/commit.md".source = prompt "commands" "commit" {agent = "build";};
          "opencode/command/pr.md".source = prompt "commands" "pr" {agent = "build";};
          "opencode/command/review.md".source = prompt "commands" "review" {
            agent = "reviewer";
            subtask = true;
          };
          "opencode/skills/git-conventions/SKILL.md".source = "${shared.skills}/git-conventions/SKILL.md";
          "opencode/opencode-notifier.json".source = ./opencode-notifier.json;
        }
        # Caveman commands
        // lib.listToAttrs (map (f: {
            name = "opencode/command/${f}";
            value.source = "${caveman}/src/plugins/opencode/commands/${f}";
          })
          cavemanCommandFiles)
        # Caveman skills (recursive deploys the whole directory tree)
        // lib.listToAttrs (map (d: {
            name = "opencode/skills/${d}";
            value = {
              source = "${caveman}/skills/${d}";
              recursive = true;
            };
          })
          cavemanSkillDirs);

      programs.opencode = {
        enable = true;
        enableMcpIntegration = true;

        # On Linux the jail installs `opencode` itself (see jail/jail.nix), so
        # the module must not also put one on PATH — the option is nullable
        # precisely for this, and everything else it generates still applies.
        # Darwin has no jail and keeps the default package.
        package = lib.mkIf pkgs.stdenv.hostPlatform.isLinux null;

        tui = {
          theme = "catppuccin-macchiato";
          mouse = true;
          scroll_acceleration.enabled = true;
          keybinds.leader = "ctrl+space";

          plugin = [
            [
              "@leohenon/opencode-vim-plugin"
              {
                enabled = true;
                vim_insert_after_submit = true;
                vim_system_clipboard_register = true;
              }
            ]
            "./herdr-tui-session.js"
          ];
        };

        context = builtins.readFile shared.context;

        settings = {
          autoupdate = false;
          default_agent = "plan";
          lsp = false;

          plugin = ["@mohak34/opencode-notifier" "@dietrichgebert/ponytail" "./plugins/caveman/plugin.js"];

          # The macmini's voice-stack ollama (macmini.nix). Model ids must be in
          # its `ollamaModels`; the context limit mirrors its
          # OLLAMA_CONTEXT_LENGTH, past which the server truncates silently.
          provider.ollama = {
            npm = "@ai-sdk/openai-compatible";
            name = "Ollama (macmini)";
            options.baseURL = "http://macmini.local:11434/v1";
            models."gpt-oss:20b" = {
              name = "gpt-oss 20b";
              limit = {
                context = 131072;
                output = 8192;
              };
            };
          };

          mcp = import ./_mcp.nix;

          permission =
            perms.sharedBase
            // {
              bash = perms.baseBash;
            }
            // perms.ghCustomTools;

          agent = import ./_agents.nix perms;
        };
      };
    };
  };
}

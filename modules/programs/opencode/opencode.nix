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

      # --- Caveman native plugin (JuliusBrussee/caveman) -----------------
      # Reimplements the opencode-specific parts of bin/install.js in Nix so
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
      cavemanInstallerHash = "4e44d73eb6843f852bb3b982407f293b2b4fa71186b5ac3c6070c3cc4e4806c4";

      cavemanInstallerCheck = pkgs.runCommand "caveman-installer-check" {} ''
        {
          grep '^const OPENCODE_' ${caveman}/bin/install.js
          awk '/^function installOpencode\(/,/^function [a-zA-Z]/' \
            ${caveman}/bin/install.js | head -n -1
          cat ${caveman}/bin/lib/opencode-agent.js
        } | sha256sum | cut -d' ' -f1 > $out

        actual=$(cat $out)
        if [ "$actual" != "${cavemanInstallerHash}" ]; then
          echo ""
          echo "ERROR: caveman's opencode installer has changed."
          echo "  expected: ${cavemanInstallerHash}"
          echo "  got:      $actual"
          echo ""
          echo "Review the installOpencode function in bin/install.js and"
          echo "bin/lib/opencode-agent.js, update the Nix reimplementation"
          echo "in opencode.nix, then set cavemanInstallerHash to the new value."
          exit 1
        fi
      '';

      # Transform agent frontmatter: strip tools: arrays and provider-less
      # model: values (e.g. "model: haiku" → dropped). Mirrors
      # bin/lib/opencode-agent.js transformOpencodeAgentFrontmatter().
      cavemanAgents = pkgs.runCommand "caveman-agents" {
        # Force a build-time dependency on the installer check.
        inherit cavemanInstallerCheck;
      } ''
        mkdir -p $out
        for f in cavecrew-investigator.md cavecrew-builder.md cavecrew-reviewer.md; do
          ${pkgs.gawk}/bin/awk '
            BEGIN { in_fm = 0; dropping = 0 }
            /^---$/ && !in_fm { in_fm = 1; print; next }
            /^---$/ && in_fm  { in_fm = 0; print; next }
            in_fm && dropping && /^[^ \t]/ { dropping = 0 }
            in_fm && dropping { next }
            in_fm && /^tools[ \t]*:/ { dropping = 1; next }
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
        "caveman-commit"
        "caveman-review"
        "caveman-help"
        "caveman-stats"
        "caveman-compress"
        "cavecrew"
      ];

      cavemanCommandFiles = [
        "caveman.md"
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

      xdg.configFile = {
        # herdr's integration check reads tui.jsonc (hardcoded, no fallback
        # to tui.json). Symlink the HM-generated file under both names so
        # opencode reads it and herdr's `tui_plugin_is_configured` finds it.
        "opencode/tui.jsonc".source =
          config.xdg.configFile."opencode/tui.json".source;

        "opencode/agent/pair.md".source = ./agents/pair.md;
        "opencode/agent/reviewer.md".source = ./agents/reviewer.md;
        "opencode/agent/troubleshoot.md".source = ./agents/troubleshoot.md;
        "opencode/agent/tickets.md".source = ./agents/tickets.md;
        "opencode/agent/test-writer.md".source = ./agents/test-writer.md;
        "opencode/command/commit.md".source = ./commands/commit.md;
        "opencode/command/pr.md".source = ./commands/pr.md;
        "opencode/command/review.md".source = ./commands/review.md;
        "opencode/skills/git-conventions/SKILL.md".source = ./skills/git-conventions/SKILL.md;
        "opencode/skills/datadog-queries/SKILL.md".source = ./skills/datadog-queries/SKILL.md;
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

        context = builtins.readFile ./context.md;

        settings = {
          model = "anthropic/claude-opus-5.5";
          autoupdate = false;
          default_agent = "plan";
          lsp = false;

          plugin = ["@mohak34/opencode-notifier" "@dietrichgebert/ponytail" "./plugins/caveman/plugin.js"];

          provider = {
            anthropic.options.apiKey = "{env:ANTHROPIC_API_KEY}";
            openai.options.apiKey = "{env:OPENAI_API_KEY}";
          };

          mcp = import ./_mcp.nix {inherit pkgs lib;};

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

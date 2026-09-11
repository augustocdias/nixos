{den, ...}: {
  den.aspects.opencode = {
    homeManager = {
      pkgs,
      lib,
      ...
    }: let
      # The bwrap jail is Linux-only, so Darwin keeps the strict allowlist as
      # its only boundary.
      perms = import ./_permissions.nix {
        jailed = pkgs.stdenv.hostPlatform.isLinux;
      };
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
      '';

      xdg.configFile = {
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
      };

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
          ];
        };

        context = builtins.readFile ./context.md;

        settings = {
          model = "anthropic/claude-opus-5";
          autoupdate = false;
          default_agent = "plan";
          lsp = false;

          plugin = ["@mohak34/opencode-notifier"];

          provider = {
            anthropic.options.apiKey = "{env:ANTHROPIC_API_KEY}";
            openai.options.apiKey = "{env:OPENAI_API_KEY}";
          };

          mcp = import ./_mcp.nix {inherit pkgs lib;};

          permission =
            perms.sharedBase
            // {
              bash = perms.readOnlyBash;
            }
            // perms.ghCustomTools;

          agent = import ./_agents.nix perms;
        };
      };
    };
  };
}

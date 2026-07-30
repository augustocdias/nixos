{
  den,
  lib,
  ...
}: let
  nvim-mcp-wrapper = pkgs:
    pkgs.writeShellScriptBin "nvim-mcp" ''
      session="''${HERDR_WORKSPACE_ID:-''${ZELLIJ_SESSION_NAME:-dettached}}"
      export NVIM_ADDRESS="$HOME/.cache/nvim/server-''${session}.pipe"
      exec ${lib.getExe' pkgs.nix "nix"} run github:paulburgess1357/nvim-mcp -- "$@"
    '';

  readOnlyBash = {
    "*" = "ask";

    # deny
    "nix build*" = "deny";
    "nix-build*" = "deny";
    "nix run*" = "deny";
    "nix develop*" = "deny";
    "nix shell*" = "deny";
    "nix profile*" = "deny";
    "nix flake check*" = "deny";
    "nix-store -r*" = "deny";
    "nix-store --realise*" = "deny";
    "nix-collect-garbage*" = "deny";
    "nixos-rebuild*" = "deny";
    "darwin-rebuild*" = "deny";
    "home-manager*" = "deny";
    "update-system*" = "deny";
    "update-nvim*" = "deny";
    "*nix build*" = "deny";
    "*nix-build*" = "deny";
    "*nix run*" = "deny";
    "*nix develop*" = "deny";
    "*nix shell*" = "deny";
    "*nix flake check*" = "deny";
    "*nixos-rebuild*" = "deny";
    "*darwin-rebuild*" = "deny";

    # -- Git: core read-only -------------------------------------------
    "git status*" = "allow";
    "git log*" = "allow";
    "git show*" = "allow";
    "git diff*" = "allow";
    "git blame*" = "allow";
    "git reflog*" = "allow";
    "git describe*" = "allow";
    "git shortlog*" = "allow";
    "git whatchanged*" = "allow";

    # -- Git: plumbing / inspection ------------------------------------
    "git rev-parse*" = "allow";
    "git symbolic-ref*" = "allow";
    "git ls-files*" = "allow";
    "git ls-remote*" = "allow";
    "git ls-tree*" = "allow";
    "git cat-file*" = "allow";
    "git rev-list*" = "allow";
    "git name-rev*" = "allow";
    "git merge-base*" = "allow";
    "git count-objects*" = "allow";
    "git fsck*" = "allow";
    "git verify-commit*" = "allow";
    "git verify-tag*" = "allow";
    "git check-ignore*" = "allow";
    "git check-attr*" = "allow";
    "git check-mailmap*" = "allow";
    "git for-each-ref*" = "allow";
    "git hash-object*" = "allow";

    # -- Git: misc read-only -------------------------------------------
    "git archive*" = "allow";
    "git bundle*" = "allow";
    "git help*" = "allow";
    "git --version*" = "allow";

    # -- Git: conditional read-only (with flags) -----------------------
    "git branch --list*" = "allow";
    "git branch -l*" = "allow";
    "git branch --show-current*" = "allow";
    "git branch --contains*" = "allow";
    "git branch --merged*" = "allow";
    "git branch --no-merged*" = "allow";
    "git remote -v*" = "allow";
    "git remote show*" = "allow";
    "git remote get-url*" = "allow";
    "git tag --list*" = "allow";
    "git tag -l*" = "allow";
    "git tag --contains*" = "allow";
    "git tag --merged*" = "allow";
    "git tag --points-at*" = "allow";
    "git config --get*" = "allow";
    "git config --get-all*" = "allow";
    "git config --get-regexp*" = "allow";
    "git config --list*" = "allow";
    "git config -l*" = "allow";
    "git stash list*" = "allow";
    "git stash show*" = "allow";
    "git worktree list*" = "allow";
    "git -C * status*" = "allow";
    "git -C * log*" = "allow";
    "git -C * diff*" = "allow";
    "git -C * show*" = "allow";
    "git -C * branch --list*" = "allow";
    "git -C * branch -a*" = "allow";
    "git -C * rev-parse*" = "allow";
    "git -C * ls-files*" = "allow";
    "git -C * for-each-ref*" = "allow";

    # -- File / directory inspection -----------------------------------
    "ls*" = "allow";
    "eza*" = "allow";
    "tree*" = "allow";
    "cat*" = "allow";
    "bat*" = "allow";
    "head*" = "allow";
    "tail*" = "allow";
    "wc*" = "allow";
    "file*" = "allow";
    "stat*" = "allow";
    "du*" = "allow";
    "df*" = "allow";
    "readlink*" = "allow";

    # -- Search --------------------------------------------------------
    "rg*" = "allow";
    "fd*" = "allow";
    "find*" = "allow";
    "find*-exec*" = "ask";
    "find*-ok*" = "ask";
    "find*-delete*" = "ask";
    "find*-fprintf*" = "ask";
    "grep*" = "allow";
    "which*" = "allow";
    "whereis*" = "allow";
    "type*" = "allow";

    # -- Text processing (read-only) -----------------------------------
    "echo*" = "allow";
    "uniq*" = "allow";
    "diff*" = "allow";
    "comm*" = "allow";
    "cut*" = "allow";
    "tr*" = "allow";
    "jq*" = "allow";
    "yq*" = "allow";
    "column*" = "allow";
    "tac*" = "allow";
    "rev*" = "allow";
    "paste*" = "allow";
    "expand*" = "allow";
    "unexpand*" = "allow";
    "fold*" = "allow";
    "fmt*" = "allow";
    "nl*" = "allow";

    # -- System info ---------------------------------------------------
    "uname*" = "allow";
    "hostname*" = "allow";
    "whoami*" = "allow";
    "id*" = "allow";
    "printenv*" = "allow";
    "date*" = "allow";
    "uptime*" = "allow";
    "pwd*" = "allow";
    "locale*" = "allow";
    "getconf*" = "allow";

    # -- Process inspection --------------------------------------------
    "ps*" = "allow";
    "pgrep*" = "allow";

    # -- Network (read-only) -------------------------------------------
    "curl*" = "allow";
    "dig*" = "allow";
    "nslookup*" = "allow";
    "ping*" = "allow";
    "host*" = "allow";

    # -- Cargo / Rust --------------------------------------------------
    "cargo check*" = "allow";
    "cargo test*" = "allow";
    "cargo clippy*" = "allow";
    "cargo build*" = "allow";
    "cargo doc*" = "allow";
    "cargo fmt --check*" = "allow";
    "cargo tree*" = "allow";
    "cargo metadata*" = "allow";
    "cargo pkgid*" = "allow";
    "cargo verify-project*" = "allow";
    "cargo bench*" = "allow";
    "rustc --version*" = "allow";
    "rustc --explain*" = "allow";
    "rustup show*" = "allow";
    "rustup target list*" = "allow";
    "rustup toolchain list*" = "allow";
    "*=* cargo *" = "allow";
    "*=* rustc *" = "allow";
    "timeout * cargo *" = "allow";
    "timeout * rustc *" = "allow";
    "*=* timeout * cargo *" = "allow";

    # -- Node / JS -----------------------------------------------------
    "node --version*" = "allow";
    "npm list*" = "allow";
    "npm info*" = "allow";
    "npm view*" = "allow";
    "npm ls*" = "allow";
    "npm outdated*" = "allow";
    "npm audit*" = "allow";
    "npm explain*" = "allow";
    "pnpm list*" = "allow";
    "pnpm info*" = "allow";
    "pnpm outdated*" = "allow";
    "pnpm audit*" = "allow";
    "npx --version*" = "allow";

    # -- Python --------------------------------------------------------
    "python3 --version*" = "allow";

    # -- Nix -----------------------------------------------------------
    "nix flake show*" = "allow";
    "nix flake metadata*" = "allow";
    "nix flake info*" = "allow";
    "nix-info*" = "allow";
    "nix path-info*" = "allow";
    "nix show-derivation*" = "allow";
    "nix-store --query*" = "allow";

    # -- Just ----------------------------------------------------------
    "just --list*" = "allow";
    "just --summary*" = "allow";
    "just --show*" = "allow";
    "just --evaluate*" = "allow";
    "just --dump*" = "allow";

    # -- GH CLI (read-only, supplements custom tools) ------------------
    "gh issue list*" = "allow";
    "gh issue view*" = "allow";
    "gh issue status*" = "allow";
    "gh pr list*" = "allow";
    "gh pr view*" = "allow";
    "gh pr diff*" = "allow";
    "gh pr checks*" = "allow";
    "gh pr status*" = "allow";
    "gh repo view*" = "allow";
    "gh repo list*" = "allow";
    "gh run list*" = "allow";
    "gh run view*" = "allow";
    "gh run watch*" = "allow";
    "gh workflow list*" = "allow";
    "gh workflow view*" = "allow";
    "gh search *" = "allow";
    "gh status*" = "allow";
    "gh auth status*" = "allow";

    # -- Herdr: inspection + topology -----------------------------------
    "herdr status*" = "allow";
    "herdr --version*" = "allow";
    "herdr session list*" = "allow";
    "herdr workspace list*" = "allow";
    "herdr workspace get*" = "allow";
    "herdr workspace create*" = "allow";
    "herdr workspace focus*" = "allow";
    "herdr tab list*" = "allow";
    "herdr tab create*" = "allow";
    "herdr tab focus*" = "allow";
    "herdr pane list*" = "allow";
    "herdr pane get*" = "allow";
    "herdr pane current*" = "allow";
    "herdr pane layout*" = "allow";
    "herdr pane process-info*" = "allow";
    "herdr pane neighbor*" = "allow";
    "herdr pane edges*" = "allow";
    "herdr pane read*" = "allow";
    "herdr pane wait-output*" = "allow";
    "herdr pane split*" = "allow";
    "herdr pane focus*" = "allow";
    "herdr pane zoom*" = "allow";
    "herdr pane rename*" = "allow";
    "herdr pane resize*" = "allow";
    "herdr agent list*" = "allow";
    "herdr agent get*" = "allow";
    "herdr agent read*" = "allow";
    "herdr agent wait*" = "allow";
    "herdr agent focus*" = "allow";
    "herdr agent rename*" = "allow";
    "herdr agent start*" = "ask";
    "herdr agent prompt*" = "ask";
    "herdr integration status*" = "allow";
    "herdr plugin list*" = "allow";
    "herdr notification show*" = "allow";
  };

  ghCustomTools = {
    gh_issue_read = "allow";
    gh_issue_write = "ask";
    gh_pr_read = "allow";
    gh_pr_write = "ask";
    gh_workflow_read = "allow";
    gh_workflow_write = "ask";
    gh_run_read = "allow";
    gh_run_write = "ask";
    gh_search = "allow";
    gh_status = "allow";
    gh_repo_read = "allow";
    gh_repo_write = "ask";
    google_calendar = "allow";
    date = "allow";
  };

  ghCustomToolsReadOnly =
    ghCustomTools
    // {
      gh_issue_write = "deny";
      gh_pr_write = "deny";
      gh_workflow_write = "deny";
      gh_run_write = "deny";
      gh_repo_write = "deny";
    };

  denyDatadog = {"datadog_*" = "deny";};

  denyTicketWrites = {
    "linear_save_*" = "deny";
    "linear_create_*" = "deny";
    "linear_delete_*" = "deny";
    "linear_prepare_attachment_upload" = "deny";
    "Notion_notion-create-*" = "deny";
    "Notion_notion-update-*" = "deny";
    "Notion_notion-move-pages" = "deny";
    "Notion_notion-duplicate-page" = "deny";
  };

  # Applied to every agent (primaries + subagents). Allows reading built
  # derivations without hitting the external-directory boundary, and lets any
  # agent ask the user questions.
  sharedBase = {
    external_directory = {
      "/nix/store/**" = "allow";
    };
    question = "allow";
  };

  primaryBase =
    sharedBase
    // {
      bash = readOnlyBash;
    }
    // ghCustomTools
    // denyDatadog
    // denyTicketWrites;
in {
  den.aspects.opencode = {
    homeManager = {
      pkgs,
      lib,
      ...
    }: {
      # FIXME: xdg.configFile creates symlinks into /nix/store which breaks Bun's
      # module resolution for @opencode-ai/plugin (it resolves relative to the real
      # path, not the symlink). We copy the files instead until this is fixed upstream.
      # https://github.com/anomalyco/opencode/issues/5914
      home.activation.opencode-tools = lib.hm.dag.entryAfter ["writeBoundary"] ''
        mkdir -p $HOME/.config/opencode/tools
        cp -f ${./tools/date.ts} $HOME/.config/opencode/tools/date.ts
        cp -f ${./tools/gh.ts} $HOME/.config/opencode/tools/gh.ts
        cp -f ${./tools/google_calendar.ts} $HOME/.config/opencode/tools/google_calendar.ts
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

          mcp =
            {
              context7 = {
                type = "local";
                command = ["npx" "-y" "@upstash/context7-mcp"];
                environment.DEFAULT_MINIMUM_TOKENS = "64000";
              };
              nvim = {
                type = "local";
                command = ["${(nvim-mcp-wrapper pkgs)}/bin/nvim-mcp"];
              };
              nixos = {
                type = "local";
                command = ["nix" "run" "github:utensils/mcp-nixos" "--"];
              };
            }
            // lib.optionalAttrs (!pkgs.stdenv.hostPlatform.isDarwin) {
              Notion = {
                type = "remote";
                url = "https://mcp.notion.com/mcp";
              };
              linear = {
                type = "local";
                command = ["npx" "-y" "mcp-remote" "https://mcp.linear.app/mcp"];
              };
              datadog = {
                type = "remote";
                url = "https://mcp.datadoghq.eu/api/unstable/mcp-server/mcp";
              };
            };

          permission =
            sharedBase
            // {
              bash = readOnlyBash;
            }
            // ghCustomTools;

          agent = {
            build.permission =
              primaryBase
              // {
                edit = "allow";
              };

            plan.permission =
              primaryBase
              // {
                edit = "deny";
              }
              // ghCustomToolsReadOnly;

            pair = {
              mode = "primary";
              description = "Read-only pairing companion: discusses, investigates, and points at code in your editor via highlights and virtual text, but never edits.";
              permission =
                primaryBase
                // ghCustomToolsReadOnly
                // {
                  edit = "deny";
                  nvim_find_and_replace_buf = "deny";
                  nvim_write_full_buf = "deny";
                  nvim_send_keys = "deny";
                  nvim_send_command = "ask";
                };
            };

            troubleshoot.permission =
              sharedBase
              // {
                edit = "deny";
                bash = readOnlyBash;
                "datadog_*" = "allow";
              }
              // ghCustomToolsReadOnly;

            tickets.permission =
              sharedBase
              // {
                edit = "deny";
                bash = readOnlyBash;
                "linear_*" = "ask";
                "Notion_*" = "ask";
              }
              // ghCustomToolsReadOnly;

            reviewer.permission =
              sharedBase
              // {
                edit = "deny";
                bash = readOnlyBash;
              }
              // ghCustomToolsReadOnly
              // denyDatadog
              // denyTicketWrites;

            "test-writer".permission =
              primaryBase
              // {
                edit = "ask";
              };
          };
        };
      };
    };
  };
}

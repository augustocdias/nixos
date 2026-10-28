{
  den,
  inputs,
  lib,
  ...
}: {
  flake-file.inputs.oh-my-pi.url = "github:can1357/oh-my-pi";
  flake-file.inputs.caveman = {
    url = lib.mkDefault "github:JuliusBrussee/caveman";
    flake = false;
  };

  den.aspects.omp = {
    homeManager = {
      pkgs,
      lib,
      config,
      ...
    }: let
      cfg = config.omp;
      jailed = pkgs.stdenv.hostPlatform.isLinux;

      shared = import ../agent-shared/_lib.nix {inherit lib;};
      devSkills = import ../agent-shared/_dev-skills.nix {inherit lib pkgs;};
      prompt = kind: name: fm:
        pkgs.writeText "${name}.md" (shared.withFrontmatter
          ({description = shared.description.${name};} // fm)
          "${shared.${kind}}/${name}.md");

      # omp has no `!`cmd`` injection in command templates, so the shared
      # bodies (written for claude) are told to run them instead.
      command = name: let
        body = builtins.readFile "${shared.commands}/${name}.md";
        lead =
          lib.optionalString (lib.hasInfix "!`" body)
          "First run each command shown in backticks below with the bash tool; its output is the context this prompt refers to.\n\n";
      in
        pkgs.writeText "${name}.md" (shared.withFrontmatterText
          {description = shared.description.${name};}
          (lead + builtins.replaceStrings ["!`"] ["`"] body));

      caveman = import ./_caveman.nix {
        inherit pkgs lib;
        caveman = inputs.caveman;
      };

      codex = model: effort: "openai-codex/${model}:${effort}";
      sol = codex "gpt-6.1-sol";
      astra = codex "gpt-6-astra";
      luna = codex "gpt-6-luna";

      settings = lib.recursiveUpdate (import ./_permissions.nix {inherit lib jailed;}) {
        theme.dark = "dark-catppuccin";
        tui.vimMode = true;
        tui.hyperlinks = "always";
        symbolPreset = "nerd";
        title.icons = "boring";
        composer.shape = "box";
        plan.defaultOnStartup = true;
        startup.checkUpdate = false;
        # Everything the first-run wizard asks is declared here.
        startup.setupWizard = false;
        marketplace.autoUpdate = "off";
        telemetry.otlpExportEnabled = false;
        astGrep.enabled = true;
        error.notify = "on";
        # Extension packages: their package.json entry plus sibling skills/,
        # commands/, agents/ and rules/ load as if plugin-installed.
        extensions = ["${caveman}" "${inputs.ponytail}"];

        modelRoles = {
          default = sol "medium";
          plan = astra "high";
          slow = astra "high";
          task = sol "medium";
          advisor = sol "medium";
          memory = sol "medium";
          commit = luna "low";
          tiny = luna "low";
          widget = luna "low";
          smol = luna "low";
        };

        task = {
          # herdr owns worktrees.
          isolation.enabled = false;
          # Wins over agent frontmatter. Work agents are harmless where absent.
          agentModelOverrides = {
            task = sol "medium";
            test-writer = sol "high";
            reviewer = astra "high";
            security-reviewer = astra "high";
            scout = luna "medium";
            cavecrew-investigator = luna "medium";
            cavecrew-builder = sol "medium";
            cavecrew-reviewer = astra "high";
            troubleshoot = astra "high";
            tickets = sol "medium";
          };
        };

        advisor.enabled = true;
        memory.backend = "mnemopi";
        # One bank: per-project keys on the absolute cwd, so every herdr
        # worktree would start with an empty memory.
        mnemopi.scoping = "global";
        autolearn.enabled = true;
        lsp.diagnosticsOnEdit = true;
        github.enabled = true;
        # Blocks stash, reset --hard and checkout/switch/restore, which would
        # pull the rug from under herdr's worktrees.
        bash.gitGuard = true;
        retry.usageAwareFallback = true;
        edit.autoRepair.enabled = true;
        checkpoint.enabled = true;

        statusLine = {
          preset = "custom";
          leftSegments = ["pi" "vim" "model" "mode" "path" "git" "pr"];
          rightSegments = ["status" "usage" "context_pct"];
          segmentOptions = {
            model.showThinkingLevel = true;
            path = {
              abbreviate = true;
              maxLength = 40;
              stripWorkPrefix = true;
            };
            git = {
              showBranch = true;
              showStaged = true;
              showUnstaged = true;
              showUntracked = true;
            };
          };
          # The `status` segment shows them; this would repeat them in the footer.
          showHookStatus = false;
        };
      };

      settingsFile = (pkgs.formats.yaml {}).generate "omp-settings.yml" settings;

      base = inputs.oh-my-pi.packages.${pkgs.stdenv.hostPlatform.system}.default;

      package = pkgs.symlinkJoin {
        name = "omp";
        paths = [base];
        nativeBuildInputs = [pkgs.makeWrapper];
        postBuild = ''
          wrapProgram $out/bin/omp --set PI_CONFIG_FILES ${settingsFile}
        '';
        meta.mainProgram = "omp";
      };

      mcpServers =
        {
          context7 = {
            type = "stdio";
            command = "npx";
            args = ["-y" "@upstash/context7-mcp"];
            env.DEFAULT_MINIMUM_TOKENS = "64000";
          };
          nixos = {
            type = "stdio";
            command = "nix";
            args = ["run" "github:utensils/mcp-nixos" "--"];
          };
        }
        // lib.optionalAttrs jailed {
          host = {
            type = "stdio";
            command = lib.getExe pkgs.python3;
            args = ["${../agent-jail/host-mcp.py}"];
          };
        }
        // cfg.mcpServers;

      # herdr owns ctrl+g, ctrl+h/j/k/l, alt+m/r/d; OmniWM owns Option with
      # h/j/k/l, shift+h/j/k/l, f, shift+f, e, t, return and the digits. Those
      # chords never reach omp, so its actions move instead. ctrl+e matches
      # Claude's setup.
      keybindings = {
        "app.editor.external" = "ctrl+e";
        "tui.editor.cursorLineEnd" = "end";
        "app.model.select" = "alt+shift+m";
        "app.retry" = "f5";
        "app.plan.toggle" = "alt+p";
        "app.model.selectTemporary" = "alt+shift+t";
        "app.live.toggle" = "alt+v";
        "app.ask.hide" = "alt+shift+a";
        "app.display.reset" = "alt+shift+r";
        "app.clipboard.copyLine" = "alt+shift+y";
        "tui.editor.cursorWordRight" = ["alt+right" "ctrl+right"];
        "tui.editor.deleteWordForward" = ["alt+delete" "ctrl+delete" "super+alt+delete" "super+alt+d"];
        "tui.input.newLine" = "shift+enter";
        # Left unbound: vim mode's D and C cover it.
        "tui.editor.deleteToLineEnd" = [];
      };
    in {
      options.omp = {
        package = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          description = "omp wrapped with the Nix-owned settings overlay. Installed by the jail on Linux.";
        };
        readOnlyTools = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          readOnly = true;
          # Mirrors Claude's read-only agents, which only lose Write/Edit, so
          # bash stays. MCP tools are additive to this list.
          default = ["read" "grep" "glob" "find" "bash" "lsp" "ast_grep" "github" "web_search" "todo"];
          description = "Built-in tool allowlist for agents that must not edit.";
        };
        mcpServers = lib.mkOption {
          type = lib.types.attrsOf (pkgs.formats.json {}).type;
          default = {};
          description = "Extra entries for ~/.omp/agent/mcp.json.";
        };
      };

      config = {
        omp.package = package;

        home.packages = lib.optional (!jailed) package;

        home.file =
          (lib.mapAttrs' (name: source: lib.nameValuePair ".omp/agent/skills/${name}" {inherit source;}) devSkills.skills)
          // {
            ".omp/agent/mcp.json".text = builtins.toJSON {inherit mcpServers;};
            ".omp/agent/keybindings.yml".source = (pkgs.formats.yaml {}).generate "keybindings.yml" keybindings;
            ".omp/agent/AGENTS.md".text =
              builtins.readFile shared.context
              + lib.optionalString jailed ("\n" + builtins.readFile ../agent-jail/jail-context.md);

            ".omp/agent/agents/test-writer.md".source = prompt "agents" "test-writer" {name = "test-writer";};
            ".omp/agent/commands/commit.md".source = command "commit";
            ".omp/agent/skills/git-conventions".source = "${shared.skills}/git-conventions";

            ".omp/agent/extensions/gate.ts".source = ./extensions/gate.ts;
            ".omp/agent/extensions/google-calendar.ts".source = ./extensions/google-calendar.ts;
            # Upstream's shared Pi/OMP extension, version-matched to the binary.
            ".omp/agent/extensions/rtk.ts".source = "${pkgs.rtk.src}/hooks/pi/rtk.ts";
          };

        home.activation.omp-dirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
          mkdir -p "$HOME/.omp" "$HOME/.config/ponytail"
        '';
      };
    };
  };
}

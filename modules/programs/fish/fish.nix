{den, ...}: {
  den.aspects.fish = {
    homeManager = {pkgs, ...}: let
      isLinux = pkgs.stdenv.hostPlatform.isLinux;

      commonAliases = {
        ls = "eza";
        ll = "eza -l";
        la = "eza -la";
        lt = "eza --tree";

        cat = "bat";
        grep = "rg";

        v = "nvim";
        vim = "nvim";

        nix-clean = "sudo nix-collect-garbage -d && nix-collect-garbage -d";
        nix-flake-update = "nix flake update --flake ~/nixos";
        nix-check = "nix flake check ~/nixos";

        gpg-restart = "gpgconf --kill gpg-agent && gpgconf --launch gpg-agent";
      };

      linuxAliases = {
        nix-history = "sudo nix profile history --profile /nix/var/nix/profiles/system";
        nix-rollback = "sudo nixos-rebuild switch --rollback";
        nix-preview = "nixos-rebuild build --flake ~/nixos#laptop -o /tmp/nixos-preview && nix store diff-closures /run/current-system /tmp/nixos-preview";

        afk = "dms ipc call lock lock";
        lock-restore = "hyprctl --instance 0 'keyword misc:allow_session_lock_restore 1' && dms ipc call lock lock";
      };

      darwinAliases = {
        nix-history = "sudo nix profile history --profile /nix/var/nix/profiles/system";
        nix-rollback = "sudo darwin-rebuild switch --rollback";
        nix-preview = "darwin-rebuild build --flake ~/nixos#macmini -o /tmp/darwin-preview && nix store diff-closures /run/current-system /tmp/darwin-preview";
      };

      commonFunctions = {};

      linuxFunctions = {
        nix-rebuild = ''
          sudo nixos-rebuild switch --flake ~/nixos#laptop $argv
        '';
      };

      darwinFunctions = {
        nix-rebuild = ''
          sudo darwin-rebuild switch --flake ~/nixos#macmini $argv
        '';
      };
    in {
      home.sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
        BROWSER = "firefox";
        TERMINAL = "ghostty";

        BAT_THEME = "Catppuccin Mocha";

        DD_SITE = "datadoghq.eu";
        JIRA_URL = "https://nelly.atlassian.net";

        GOPATH = "$HOME/.go";
        GOBIN = "$HOME/.go/bin";

        GITHUB_USER = "augustocdias";
        SEARXNG_API_URL = "https://searx.oloke.xyz/";
      };

      programs.fish = {
        enable = true;

        plugins = [
          {
            name = "colored-man-pages";
            inherit (pkgs.fishPlugins.colored-man-pages) src;
          }
          {
            name = "foreign-env";
            inherit (pkgs.fishPlugins.foreign-env) src;
          }
          {
            name = "puffer";
            inherit (pkgs.fishPlugins.puffer) src;
          }
          {
            name = "enhancd";
            src = fetchGit {
              url = "https://github.com/babarot/enhancd";
              rev = "5afb4eb6ba36c15821de6e39c0a7bb9d6b0ba415";
            };
          }
          {
            name = "plugin-wttr";
            src = fetchGit {
              url = "https://github.com/oh-my-fish/plugin-wttr";
              rev = "7500e382e6b29a463edc57598217ce0cfaf8c90c";
            };
          }
        ];

        shellInit = ''
          # Non-interactive shell initialization
        '';

        interactiveShellInit = ''
          source ${./init.fish}
        '';

        shellAliases =
          commonAliases
          // (
            if isLinux
            then linuxAliases
            else darwinAliases
          );

        functions =
          commonFunctions
          // (
            if isLinux
            then linuxFunctions
            else darwinFunctions
          );

        shellAbbrs = {
          g = "git";
          gco = "git co";
          gm = "git cm";
          ga = "git a";
          gaa = "git aa";
          gp = "git pull origin";
          gu = "git push origin";
          gsb = "git status -sb";

          p = "pnpm";
          pi = "pnpm install";
          pd = "pnpm dev";

          lc = "llm commit";
          lcy = "llm commit --yes";
        };
      };
    };
  };
}

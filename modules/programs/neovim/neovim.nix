{
  den,
  inputs,
  lib,
  ...
}: let
  mkPlugin = url: {
    url = lib.mkDefault url;
    flake = false;
  };
  mkFlakePlugin = url: {
    url = lib.mkDefault url;
    inputs.nixpkgs.follows = "nixpkgs";
  };
in {
  flake-file.inputs = {
    neovim-nightly-overlay = mkFlakePlugin "github:nix-community/neovim-nightly-overlay";

    # Flake-enabled plugins (use their package outputs)
    nvim-blink-cmp = mkFlakePlugin "github:Saghen/blink.cmp";
    nvim-blink-pairs = mkFlakePlugin "github:saghen/blink.pairs";
    nvim-lze = mkFlakePlugin "github:BirdeeHub/lze";
    nvim-rustaceanvim = mkFlakePlugin "github:mrcjkb/rustaceanvim";

    # Source-only plugins (nvim- prefix for selective updates via update-neovim-plugins)
    nvim-gx = mkPlugin "github:chrishrb/gx.nvim";
    nvim-plenary = mkPlugin "github:nvim-lua/plenary.nvim";
    nvim-nui = mkPlugin "github:MunifTanjim/nui.nvim";
    nvim-nvim-lspconfig = mkPlugin "github:neovim/nvim-lspconfig";
    nvim-SchemaStore = mkPlugin "github:b0o/SchemaStore.nvim";
    nvim-nvim-treesitter-textobjects = mkPlugin "github:nvim-treesitter/nvim-treesitter-textobjects";
    nvim-nvim-treesitter-context = mkPlugin "github:nvim-treesitter/nvim-treesitter-context";
    nvim-catppuccin = mkPlugin "github:catppuccin/nvim";
    nvim-tokyonight = mkPlugin "github:folke/tokyonight.nvim";
    nvim-lualine = mkPlugin "github:nvim-lualine/lualine.nvim";
    nvim-which-key = mkPlugin "github:folke/which-key.nvim";
    nvim-noice = mkPlugin "github:folke/noice.nvim";
    nvim-nvim-notify = mkPlugin "github:rcarriga/nvim-notify";
    nvim-tabby = mkPlugin "github:nanozuki/tabby.nvim";
    nvim-dropbar = mkPlugin "github:Bekaboo/dropbar.nvim";
    nvim-auto-session = mkPlugin "github:rmagatti/auto-session";
    nvim-snacks = mkPlugin "github:folke/snacks.nvim";
    nvim-helpview = mkPlugin "github:OXY2DEV/helpview.nvim";
    nvim-tabout = mkPlugin "github:abecodes/tabout.nvim";
    nvim-colorful-menu = mkPlugin "github:xzbdmw/colorful-menu.nvim";
    nvim-gitsigns = mkPlugin "github:lewis6991/gitsigns.nvim";
    nvim-diffview = mkPlugin "github:dlyongemallo/diffview.nvim";
    nvim-octo = mkPlugin "github:pwntester/octo.nvim";
    nvim-flash = mkPlugin "github:folke/flash.nvim";
    nvim-trouble = mkPlugin "github:folke/trouble.nvim";
    nvim-todo-comments = mkPlugin "github:folke/todo-comments.nvim";
    nvim-vim-matchup = mkPlugin "github:andymass/vim-matchup";
    nvim-mini-icons = mkPlugin "github:nvim-mini/mini.icons";
    nvim-mini-ai = mkPlugin "github:nvim-mini/mini.ai";
    nvim-mini-files = mkPlugin "github:nvim-mini/mini.files";
    nvim-mini-move = mkPlugin "github:nvim-mini/mini.move";
    nvim-mini-surround = mkPlugin "github:nvim-mini/mini.surround";
    nvim-conform = mkPlugin "github:stevearc/conform.nvim";
    nvim-nvim-lint = mkPlugin "github:mfussenegger/nvim-lint";
    nvim-lightbulb = mkPlugin "github:kosayoda/nvim-lightbulb";

    nvim-markview = mkPlugin "github:OXY2DEV/markview.nvim";

    nvim-gatekeeper = mkPlugin "github:augustocdias/gatekeeper.nvim";
    nvim-codesnap = mkPlugin "github:mistricky/codesnap.nvim";

    nvim-crates = mkPlugin "github:Saecki/crates.nvim";
    nvim-refactoring = mkPlugin "github:ThePrimeagen/refactoring.nvim";
    nvim-markdown-plus = mkPlugin "github:yousefhadder/markdown-plus.nvim";
  };

  den.aspects.neovim = {
    nixos.nixpkgs.overlays = lib.optionals (inputs ? neovim-nightly-overlay) [
      inputs.neovim-nightly-overlay.overlays.default
    ];

    homeManager = {
      pkgs,
      config,
      ...
    }: let
      customPlugins = import ./_plugins.nix {inherit pkgs lib inputs;};
    in {
      programs.neovim = {
        enable = true;
        package = pkgs.neovim;
        vimAlias = true;
        viAlias = true;

        plugins =
          customPlugins.pluginList
          ++ [
            (pkgs.vimPlugins.nvim-treesitter.withPlugins (p:
              with p; [
                bash
                c
                comment
                cpp
                c_sharp
                css
                diff
                dockerfile
                editorconfig
                fish
                gdscript
                godot_resource
                gdshader
                git_config
                git_rebase
                gitattributes
                gitcommit
                gitignore
                html
                java
                javascript
                jsdoc
                json
                json5
                kdl
                kotlin
                lua
                luadoc
                markdown
                markdown_inline
                nix
                python
                qmljs
                query
                regex
                rust
                sql
                swift
                toml
                typescript
                tsx
                vim
                vimdoc
                yaml
              ]))
          ];

        extraPackages = with pkgs; [
          bash-language-server
          yaml-language-server
          vscode-json-languageserver
          dockerfile-language-server
          docker-compose-language-service
          taplo
          emmylua-ls
          typescript
          rust-analyzer
          typescript-go
          nixd

          black
          stylua
          prettier
          shfmt
          alejandra
          sqlfluff
          mdformat

          harper
          eslint
          codespell
          selene
          yamllint
          hadolint
          actionlint
          deadnix
          write-good
          markdownlint-cli
          statix
        ];
      };

      # Symlink to repo checkout for live editing without rebuild
      xdg.configFile."nvim" = {
        source =
          config.lib.file.mkOutOfStoreSymlink
          "${config.home.homeDirectory}/nixos/modules/programs/neovim/configs";
      };

      programs.neovim.sideloadInitLua = true;

      home.packages = [
        (pkgs.writeScriptBin "update-nvim" (builtins.readFile ./update-plugins.fish))
      ];

      home.sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };
    };
  };
}

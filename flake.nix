# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  description = "NixOS system with Hyprland";

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    catppuccin-grub = {
      url = "github:catppuccin/grub/0a37ab19f654e77129b409fed371891c01ffd0b9";
      flake = false;
    };
    darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    den.url = "github:vic/den";
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dms-plugins = {
      url = "github:AvengeMedia/dms-plugin-registry";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-aspects.url = "github:vic/flake-aspects";
    flake-file.url = "github:vic/flake-file";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
    import-tree.url = "github:vic/import-tree";
    jetbrains-plugins = {
      url = "github:Janrupf/nix-jetbrains-plugin-repository";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim-nightly-overlay = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nvim-SchemaStore = {
      url = "github:b0o/SchemaStore.nvim";
      flake = false;
    };
    nvim-auto-session = {
      url = "github:rmagatti/auto-session";
      flake = false;
    };
    nvim-blink-cmp = {
      url = "github:Saghen/blink.cmp";
      inputs = {
        blink-lib.follows = "nvim-blink-lib";
        nixpkgs.follows = "nixpkgs";
      };
    };
    nvim-blink-lib = {
      url = "github:saghen/blink.lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvim-blink-pairs = {
      url = "github:saghen/blink.pairs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvim-catppuccin = {
      url = "github:catppuccin/nvim";
      flake = false;
    };
    nvim-codesnap = {
      url = "github:mistricky/codesnap.nvim";
      flake = false;
    };
    nvim-colorful-menu = {
      url = "github:xzbdmw/colorful-menu.nvim";
      flake = false;
    };
    nvim-conform = {
      url = "github:stevearc/conform.nvim";
      flake = false;
    };
    nvim-crates = {
      url = "github:Saecki/crates.nvim";
      flake = false;
    };
    nvim-diffview = {
      url = "github:dlyongemallo/diffview.nvim";
      flake = false;
    };
    nvim-dropbar = {
      url = "github:Bekaboo/dropbar.nvim";
      flake = false;
    };
    nvim-flash = {
      url = "github:folke/flash.nvim";
      flake = false;
    };
    nvim-gatekeeper = {
      url = "github:augustocdias/gatekeeper.nvim";
      flake = false;
    };
    nvim-gitsigns = {
      url = "github:lewis6991/gitsigns.nvim";
      flake = false;
    };
    nvim-gx = {
      url = "github:chrishrb/gx.nvim";
      flake = false;
    };
    nvim-helpview = {
      url = "github:OXY2DEV/helpview.nvim";
      flake = false;
    };
    nvim-lightbulb = {
      url = "github:kosayoda/nvim-lightbulb";
      flake = false;
    };
    nvim-lualine = {
      url = "github:nvim-lualine/lualine.nvim";
      flake = false;
    };
    nvim-lze = {
      url = "github:BirdeeHub/lze";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvim-markdown-plus = {
      url = "github:yousefhadder/markdown-plus.nvim";
      flake = false;
    };
    nvim-markview = {
      url = "github:OXY2DEV/markview.nvim";
      flake = false;
    };
    nvim-mini-ai = {
      url = "github:nvim-mini/mini.ai";
      flake = false;
    };
    nvim-mini-files = {
      url = "github:nvim-mini/mini.files";
      flake = false;
    };
    nvim-mini-icons = {
      url = "github:nvim-mini/mini.icons";
      flake = false;
    };
    nvim-mini-move = {
      url = "github:nvim-mini/mini.move";
      flake = false;
    };
    nvim-mini-surround = {
      url = "github:nvim-mini/mini.surround";
      flake = false;
    };
    nvim-noice = {
      url = "github:folke/noice.nvim";
      flake = false;
    };
    nvim-nui = {
      url = "github:MunifTanjim/nui.nvim";
      flake = false;
    };
    nvim-nvim-lint = {
      url = "github:mfussenegger/nvim-lint";
      flake = false;
    };
    nvim-nvim-lspconfig = {
      url = "github:neovim/nvim-lspconfig";
      flake = false;
    };
    nvim-nvim-notify = {
      url = "github:rcarriga/nvim-notify";
      flake = false;
    };
    nvim-nvim-treesitter-context = {
      url = "github:nvim-treesitter/nvim-treesitter-context";
      flake = false;
    };
    nvim-nvim-treesitter-textobjects = {
      url = "github:nvim-treesitter/nvim-treesitter-textobjects";
      flake = false;
    };
    nvim-octo = {
      url = "github:pwntester/octo.nvim";
      flake = false;
    };
    nvim-plenary = {
      url = "github:nvim-lua/plenary.nvim";
      flake = false;
    };
    nvim-refactoring = {
      url = "github:ThePrimeagen/refactoring.nvim";
      flake = false;
    };
    nvim-rustaceanvim = {
      url = "github:mrcjkb/rustaceanvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvim-snacks = {
      url = "github:folke/snacks.nvim";
      flake = false;
    };
    nvim-tabby = {
      url = "github:nanozuki/tabby.nvim";
      flake = false;
    };
    nvim-tabout = {
      url = "github:abecodes/tabout.nvim";
      flake = false;
    };
    nvim-todo-comments = {
      url = "github:folke/todo-comments.nvim";
      flake = false;
    };
    nvim-tokyonight = {
      url = "github:folke/tokyonight.nvim";
      flake = false;
    };
    nvim-trouble = {
      url = "github:folke/trouble.nvim";
      flake = false;
    };
    nvim-vim-matchup = {
      url = "github:andymass/vim-matchup";
      flake = false;
    };
    nvim-which-key = {
      url = "github:folke/which-key.nvim";
      flake = false;
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sqlit = {
      url = "github:Maxteabag/sqlit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}

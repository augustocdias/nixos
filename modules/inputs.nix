{lib, ...}: {
  flake-file.description = "NixOS system with Hyprland";

  flake-file.inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    den.url = "github:vic/den";
    flake-aspects.url = "github:vic/flake-aspects";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    flake-file.url = "github:vic/flake-file";

    home-manager = {
      url = lib.mkDefault "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = lib.mkDefault "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = lib.mkDefault "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew = {
      url = lib.mkDefault "github:zhaofengli/nix-homebrew";
    };
  };
}

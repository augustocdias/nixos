{
  den,
  inputs,
  lib,
  ...
}: let
  sharedNixModule = {pkgs, ...}: {
    nixpkgs.config.allowUnfree = true;

    nix = {
      settings = {
        experimental-features = ["nix-command" "flakes"];
        extra-substituters = [
          "https://hyprland.cachix.org"
          "https://nix-community.cachix.org"
        ];
        extra-trusted-public-keys = [
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };
      gc = {
        automatic = true;
        options = "--delete-older-than 30d";
      };
      optimise.automatic = true;
    };

    environment.systemPackages = with pkgs; [
      coreutils
      curl
      wget
      git
    ];
  };
in {
  den.schema.user.classes = lib.mkDefault ["homeManager"];

  den.ctx.hm-host = {
    nixos.home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-bak";
      sharedModules = lib.optionals (inputs ? sops-nix) [
        inputs.sops-nix.homeManagerModules.sops
      ];
    };
    darwin.home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "hm-bak";
      sharedModules = lib.optionals (inputs ? sops-nix) [
        inputs.sops-nix.homeManagerModules.sops
      ];
    };
  };

  den.default = {
    nixos = {...}: {
      imports = [sharedNixModule];

      # NixOS-only schedule fields
      nix.gc.dates = "weekly";
      nix.optimise.dates = ["weekly"];

      system.stateVersion = "26.05";
    };

    darwin = {...}: {
      imports = [sharedNixModule];

      nix.gc.interval = {
        Weekday = 0;
        Hour = 3;
      };
      nix.optimise.interval = {
        Weekday = 0;
        Hour = 4;
      };

      system.stateVersion = 6;
    };

    homeManager.home.stateVersion = "26.05";

    includes = [
      den._.define-user
      den._.primary-user
      den._.hostname
      (den._.user-shell "fish")
    ];
  };
}

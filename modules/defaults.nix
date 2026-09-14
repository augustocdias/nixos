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
          "https://nixos-raspberrypi.cachix.org"
        ];
        extra-trusted-public-keys = [
          "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
        ];
      };
      gc = {
        automatic = true;
        options = "--delete-older-than 30d";
      };
      optimise.automatic = pkgs.stdenv.hostPlatform.isLinux;
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

  den.schema.hm-host.includes = [
    {
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
    }
  ];

  den.default = {
    nixos = {...}: {
      imports = [sharedNixModule];

      nix.gc.dates = "weekly";
      nix.optimise.dates = ["weekly"];

      system.stateVersion = "26.11";
    };

    darwin = {...}: {
      imports = [sharedNixModule];

      nix.gc.interval = {
        Weekday = 0;
        Hour = 3;
      };
      system.stateVersion = 6;
    };

    homeManager.home.stateVersion = "26.11";

    includes = [
      den._.define-user
      den._.primary-user
      den._.hostname
      (den._.user-shell "fish")
    ];
  };
}

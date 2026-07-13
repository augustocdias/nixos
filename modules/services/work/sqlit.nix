{
  den,
  inputs,
  lib,
  ...
}: {
  flake-file.inputs.sqlit = {
    url = lib.mkDefault "github:Maxteabag/sqlit";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.sqlit = {
    nixos.nixpkgs.overlays = lib.optionals (inputs ? sqlit) [
      (_: prev: {
        sqlit-with-postgres = inputs.sqlit.lib.${prev.stdenv.hostPlatform.system}.makeSqlit {
          extras = ["postgres"];
        };
      })
    ];

    homeManager = {pkgs, ...}: {
      home.packages = [pkgs.sqlit-with-postgres];
    };
  };
}

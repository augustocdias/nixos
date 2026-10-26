{
  den,
  inputs,
  lib,
  ...
}: {
  flake-file.inputs.zapfast = {
    url = lib.mkDefault "github:crmne/zapfast";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.zapfast = {
    homeManager = {pkgs, ...}: {
      home.packages = [inputs.zapfast.packages.${pkgs.stdenv.hostPlatform.system}.default];
    };
  };
}

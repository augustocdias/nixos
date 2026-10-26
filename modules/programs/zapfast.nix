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
    homeManager = {
      imports = [inputs.zapfast.homeManagerModules.default];

      programs.zapfast = {
        enable = true;
        settings = {
          check_for_updates = false;
          group_sounds = false;
          message_sound = "none";
          mention_sound = "none";
        };
      };
    };
  };
}

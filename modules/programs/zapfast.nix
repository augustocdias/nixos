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
      imports = [inputs.zapfast.homeManagerModules.default];

      programs.zapfast = {
        enable = true;
        # nixpkgs' cargoSetupHook exports OPENSSL_NO_VENDOR and LIBSQLITE3_SYS_USE_PKG_CONFIG,
        # disabling zapfast's vendored OpenSSL and SQLCipher; link the system ones.
        package = inputs.zapfast.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
          buildInputs = old.buildInputs ++ [pkgs.openssl pkgs.sqlcipher];
        });
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

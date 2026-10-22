{
  den,
  inputs,
  lib,
  ...
}: {
  flake-file.inputs.jail-nix.url = lib.mkDefault "sourcehut:~alexdavid/jail.nix";

  den.aspects.omp-jail = {
    homeManager = {
      pkgs,
      config,
      ...
    }: let
      mkJail = import ../../agent-jail/_mk-jail.nix {inherit inputs lib pkgs config;};

      jailed = mkJail {
        name = "omp";
        inherit (config.omp) package;

        extra = c:
          with c; [
            (try-rw-bind (noescape "\"$HOME/.omp\"") (noescape "~/.omp"))
            (try-rw-bind (noescape "\"$HOME/.config/ponytail\"") (noescape "~/.config/ponytail"))
            (try-rw-bind (noescape "\"$HOME/.cache/jgrep\"") (noescape "~/.cache/jgrep"))
          ];
      };
    in {
      home.packages = [jailed];
    };
  };
}

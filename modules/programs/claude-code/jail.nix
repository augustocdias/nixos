{
  den,
  inputs,
  lib,
  ...
}: {
  den.aspects.claude-code-jail = {
    homeManager = {
      pkgs,
      config,
      ...
    }: let
      mkJail = import ../agent-jail/_mk-jail.nix {inherit inputs lib pkgs config;};

      jailed = mkJail {
        name = "claude";
        package = pkgs.claude-code;

        extra = c:
          with c; [
            (set-env "CLAUDE_CONFIG_DIR" (noescape "\"$HOME/.claude\""))
            (try-rw-bind (noescape "\"$HOME/.claude\"") (noescape "~/.claude"))
            (try-rw-bind (noescape "\"$HOME/.cache/jgrep\"") (noescape "~/.cache/jgrep"))
          ];
      };
    in {
      home.packages = [jailed];
    };
  };
}

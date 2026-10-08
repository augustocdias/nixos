{
  den,
  inputs,
  lib,
  ...
}: {
  flake-file.inputs.jail-nix.url = lib.mkDefault "sourcehut:~alexdavid/jail.nix";

  den.aspects.opencode-jail = {
    homeManager = {
      pkgs,
      config,
      ...
    }: let
      mkJail = import ../../agent-jail/_mk-jail.nix {inherit inputs lib pkgs config;};

      jailConfig = pkgs.writeTextDir "opencode.json" (builtins.toJSON {
        "$schema" = "https://opencode.ai/config.json";
        instructions = ["${../../agent-jail/jail-context.md}"];
      });

      jailed = mkJail {
        name = "opencode";
        package = pkgs.opencode;

        pre = c:
          with c; [
          (add-runtime ''
            # The config half ships separately (home.activation, xdg.configFile).
            # If it is older than this jail, jail-context.md describes tools and
            # permissions that are not actually there — so refuse rather than
            # hand an agent a document that lies to it.
            sync_expected=${import ../_sync.nix}
            sync_actual=$(cat "$HOME/.config/opencode/.sync-id" 2>/dev/null || echo none)
            if [ "$sync_actual" != "$sync_expected" ] \
              && [ -z "''${OPENCODE_JAIL_SKIP_SYNC_CHECK:-}" ]; then
              echo "opencode-jail: refusing to start — the deployed opencode config" >&2
              echo "  does not match this sandbox." >&2
              echo "    sandbox expects: $sync_expected" >&2
              echo "    config provides: $sync_actual" >&2
              echo "  In this state the host_* tools, the bash allowlist and" >&2
              echo "  jail-context.md can all disagree with each other." >&2
              echo "  Fix:  sudo nixos-rebuild switch --flake ." >&2
              echo "  Override (not recommended): OPENCODE_JAIL_SKIP_SYNC_CHECK=1" >&2
              exit 1
            fi
          '')
        ];

        extra = c:
          with c; [
          (overlay-tmp [(noescape "\"$HOME/.config/opencode\"")] (noescape "~/.config/opencode"))
          (overlay-tmp ["${jailConfig}"] (noescape "~/.config/opencode-jail"))
          (set-env "OPENCODE_CONFIG_DIR" (noescape "\"$HOME/.config/opencode-jail\""))
          (try-rw-bind (noescape "\"$HOME/.local/share/opencode\"") (noescape "~/.local/share/opencode"))
          (try-rw-bind (noescape "\"$HOME/.local/state/opencode\"") (noescape "~/.local/state/opencode"))
          (try-rw-bind (noescape "\"$HOME/.cache/opencode\"") (noescape "~/.cache/opencode"))
        ];
      };
    in {
      home.packages = [jailed];
    };
  };
}

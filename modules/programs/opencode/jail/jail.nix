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
      jail = inputs.jail-nix.lib.extend {
        inherit pkgs;
        suppressExperimentalWarnings = true;
      };

      inherit (config.home) username;

      git = lib.getExe pkgs.git;
      curl = lib.getExe pkgs.curl;

      hostQuery = pkgs.callPackage ./_host-query {};

      rmSafe = pkgs.symlinkJoin {
        name = "opencode-jail-rm-safe";
        paths = [
          (pkgs.writeShellScriptBin "rm" ''exec ${lib.getExe' pkgs.rmtrash "rmtrash"} "$@"'')
          (pkgs.writeShellScriptBin "rmdir" ''exec ${lib.getExe' pkgs.rmtrash "rmdirtrash"} "$@"'')
        ];
      };

      gitSshDeny = pkgs.writeShellScript "opencode-jail-git-ssh-denied" ''
        echo "opencode-jail: git over SSH is disabled inside the sandbox." >&2
        echo "  Stage your work and let the user push from the host." >&2
        exit 1
      '';

      jailConfig = pkgs.writeTextDir "opencode.json" (builtins.toJSON {
        "$schema" = "https://opencode.ai/config.json";
        instructions = ["${./jail-context.md}"];
      });

      jailed = jail "opencode" pkgs.opencode (
        with jail.combinators; [
          reset
          (unsafe-add-raw-args "--proc /proc")
          (unsafe-add-raw-args "--dev /dev")
          (unsafe-add-raw-args "--tmpfs /tmp")
          (unsafe-add-raw-args "--tmpfs ~")
          (ro-bind "${pkgs.bash}/bin/sh" "/bin/sh")
          fake-passwd
          (unsafe-add-raw-args "--unsetenv SSH_AUTH_SOCK")

          network
          no-new-session

          (ro-bind "/nix/store" "/nix/store")
          (set-env "NIX_REMOTE" "daemon")
          (try-rw-bind "/nix/var/nix/daemon-socket" "/nix/var/nix/daemon-socket")
          (try-readonly "/nix/var/nix/db")
          (try-readonly "/nix/var/nix/profiles")
          (try-readonly "/etc/nix")
          (try-readonly "/etc/static")

          (try-readonly "/run/current-system/sw")
          (try-readonly "/etc/profiles/per-user/${username}")

          (ro-bind "${pkgs.coreutils}/bin/env" "/usr/bin/env")

          mount-cwd

          (add-runtime ''
            if git_common=$(${git} rev-parse --git-common-dir 2>/dev/null) \
              && git_dir=$(${git} rev-parse --git-dir 2>/dev/null) \
              && [ "$git_common" != "$git_dir" ]; then
              git_common=$(realpath "$git_common")
              RUNTIME_ARGS+=(--bind "$git_common" "$git_common")
            fi
          '')

          (add-runtime ''
            jail_state="$HOME/.local/share/opencode-jail"
            grant_root="$jail_state/grants/$$"
            mkdir -p "$grant_root" "$jail_state/log"

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

            # Sweep grants left by sessions that died without running cleanup.
            for stale in "$jail_state"/grants/*; do
              [ -d "$stale" ] || continue
              kill -0 "''${stale##*/}" 2>/dev/null && continue
              for mnt in "$stale"/*; do
                [ -d "$mnt" ] || continue
                /run/wrappers/bin/fusermount3 -u "$mnt" 2>/dev/null || true
                rmdir "$mnt" 2>/dev/null || true
              done
              rmdir "$stale" 2>/dev/null || true
            done

            host_query_port=19600
            while [ "$host_query_port" -lt 19800 ]; do
              (exec 3<>/dev/tcp/127.0.0.1/"$host_query_port") 2>/dev/null || break
              host_query_port=$((host_query_port + 1))
            done

            ${lib.getExe hostQuery} "$host_query_port" "$grant_root" \
              > "$jail_state/log/host-query.log" 2>&1 &
            HOST_QUERY_PID=$!

            host_query_up=
            for _ in $(seq 1 20); do
              if ${curl} -sf "http://127.0.0.1:$host_query_port/health" >/dev/null 2>&1; then
                host_query_up=1
                break
              fi
              sleep 0.25
            done
            if [ -z "$host_query_up" ]; then
              echo "opencode-jail: warning: host-query did not start on port $host_query_port" >&2
              echo "  host_exec / host_mount / host_journal will be unavailable;" >&2
              echo "  see $jail_state/log/host-query.log" >&2
            fi

            RUNTIME_ARGS+=(
              --bind "$grant_root" "$HOME/granted"
              # Read-only: the log is the first thing to check when a host_*
              # tool misbehaves, and it is unreachable if only grants/ is bound.
              --ro-bind "$jail_state/log" "$jail_state/log"
              --setenv HOST_QUERY_PORT "$host_query_port"
            )
          '')
          (add-cleanup ''
            kill "''${HOST_QUERY_PID:-}" 2>/dev/null || true
            if [ -n "''${grant_root:-}" ]; then
              for mnt in "$grant_root"/*; do
                [ -d "$mnt" ] || continue
                /run/wrappers/bin/fusermount3 -u "$mnt" 2>/dev/null || true
                rmdir "$mnt" 2>/dev/null || true
              done
              rmdir "$grant_root" 2>/dev/null || true
            fi
          '')

          (overlay-tmp [(noescape "\"$HOME/.config/opencode\"")] (noescape "~/.config/opencode"))
          (overlay-tmp ["${jailConfig}"] (noescape "~/.config/opencode-jail"))
          (set-env "OPENCODE_CONFIG_DIR" (noescape "\"$HOME/.config/opencode-jail\""))
          (try-rw-bind (noescape "\"$HOME/.local/share/opencode\"") (noescape "~/.local/share/opencode"))
          (try-rw-bind (noescape "\"$HOME/.local/state/opencode\"") (noescape "~/.local/state/opencode"))
          (try-rw-bind (noescape "\"$HOME/.cache/opencode\"") (noescape "~/.cache/opencode"))

          (add-runtime ''
            nvim_sock="$HOME/.cache/nvim/server-''${HERDR_WORKSPACE_ID:-dettached}.pipe"
            if [ -S "$nvim_sock" ]; then
              RUNTIME_ARGS+=(--bind "$nvim_sock" "$nvim_sock")
            fi
          '')

          (try-readonly (noescape "\"$HOME/.config/git\""))
          (try-readonly (noescape "\"$HOME/.config/gh\""))
          (set-env "GIT_CONFIG_COUNT" "1")
          (set-env "GIT_CONFIG_KEY_0" "core.sshCommand")
          (set-env "GIT_CONFIG_VALUE_0" "${gitSshDeny}")

          (defer (set-env "PATH" (noescape "\"${rmSafe}/bin:$PATH\"")))

          (try-readonly (noescape "\"$HOME/.config/direnv\""))

          (try-rw-bind (noescape "\"$HOME/.cache/nix\"") (noescape "~/.cache/nix"))
          (try-rw-bind (noescape "\"$HOME/.npm\"") (noescape "~/.npm"))
          (try-rw-bind (noescape "\"$HOME/.bun\"") (noescape "~/.bun"))
          (try-rw-bind (noescape "\"$HOME/.cargo/registry\"") (noescape "~/.cargo/registry"))
          (try-rw-bind (noescape "\"$HOME/.cargo/git\"") (noescape "~/.cargo/git"))
          (try-rw-bind (noescape "\"$HOME/.local/share/direnv\"") (noescape "~/.local/share/direnv"))
        ]
      );
    in {
      home.packages = [jailed];
    };
  };
}

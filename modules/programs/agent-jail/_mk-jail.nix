# Bubblewrap jail shared by every coding agent (omp, claude).
#
# Usage: import ./_mk-jail.nix {inherit inputs lib pkgs config;} {
#   name    = "claude";        # installed binary name, and the state dir prefix
#   package = pkgs.claude-code;
#   pre     = c: [ ... ];      # combinators that run before host-query starts
#   extra   = c: [ ... ];      # agent-specific binds and env
# `c` is jail-nix's combinator set, already extended with pkgs.
# }
{
  inputs,
  lib,
  pkgs,
  config,
}: {
  name,
  package,
  pre ? (_: []),
  extra ? (_: []),
}: let
  jail = inputs.jail-nix.lib.extend {
    inherit pkgs;
    suppressExperimentalWarnings = true;
  };

  inherit (config.home) username;

  git = lib.getExe pkgs.git;
  curl = lib.getExe pkgs.curl;

  hostQuery = pkgs.callPackage ./_host-query {};
  herdrRelay = pkgs.callPackage ./_herdr-relay {};

  rmSafe = pkgs.symlinkJoin {
    name = "agent-jail-rm-safe";
    paths = [
      (pkgs.writeShellScriptBin "rm" ''exec ${lib.getExe' pkgs.rmtrash "rmtrash"} "$@"'')
      (pkgs.writeShellScriptBin "rmdir" ''exec ${lib.getExe' pkgs.rmtrash "rmdirtrash"} "$@"'')
    ];
  };
in
  jail name package (
    with jail.combinators;
      [
        reset
        (unsafe-add-raw-args "--proc /proc")
        (unsafe-add-raw-args "--dev /dev")
        (unsafe-add-raw-args "--tmpfs /tmp")
        (unsafe-add-raw-args "--tmpfs ~")
        (ro-bind "${pkgs.bash}/bin/sh" "/bin/sh")
        fake-passwd

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
          unset GPG_TTY
          if git_common=$(${git} rev-parse --git-common-dir 2>/dev/null) \
            && git_dir=$(${git} rev-parse --git-dir 2>/dev/null) \
            && [ "$git_common" != "$git_dir" ]; then
            git_common=$(realpath "$git_common")
            RUNTIME_ARGS+=(--bind "$git_common" "$git_common")
          fi
        '')
      ]
      ++ pre jail.combinators
      ++ [
        (add-runtime ''
          jail_state="$HOME/.local/share/${name}-jail"
          grant_root="$jail_state/grants/$$"
          mkdir -p "$grant_root" "$jail_state/log"

          # Sweep grants left by sessions that died without running cleanup.
          for stale in "$jail_state"/grants/*; do
            [ -d "$stale" ] || continue
            kill -0 "''${stale##*/}" 2>/dev/null && continue
            rm -f "$stale/ssh-agent.sock"
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

          # Not bound into the jail: host_ssh_agent relays it on approval.
          HOST_SSH_AUTH_SOCK="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gnupg/S.gpg-agent.ssh" \
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
            echo "${name}-jail: warning: host-query did not start on port $host_query_port" >&2
            echo "  host_exec / host_mount / host_journal / host_ssh_agent will be unavailable;" >&2
            echo "  see $jail_state/log/host-query.log" >&2
          fi

          RUNTIME_ARGS+=(
            --bind "$grant_root" "$HOME/granted"
            # Read-only: the log is the first thing to check when a host_*
            # tool misbehaves, and it is unreachable if only grants/ is bound.
            --ro-bind "$jail_state/log" "$jail_state/log"
            --setenv HOST_QUERY_PORT "$host_query_port"
            # The inherited host value points at a socket the jail cannot see.
            --unsetenv SSH_AUTH_SOCK
          )
        '')
        (add-cleanup ''
          kill "''${HOST_QUERY_PID:-}" 2>/dev/null || true
          if [ -n "''${grant_root:-}" ]; then
            rm -f "$grant_root/ssh-agent.sock"
            for mnt in "$grant_root"/*; do
              [ -d "$mnt" ] || continue
              /run/wrappers/bin/fusermount3 -u "$mnt" 2>/dev/null || true
              rmdir "$mnt" 2>/dev/null || true
            done
            rmdir "$grant_root" 2>/dev/null || true
          fi
        '')

        (try-readonly (noescape "\"$HOME/.config/git\""))
        (try-readonly (noescape "\"$HOME/.config/gh\""))

        (try-ro-bind (noescape "\"$HOME/.ssh/known_hosts\"") (noescape "~/.ssh/known_hosts"))

        (defer (set-env "PATH" (noescape "\"${rmSafe}/bin:$PATH\"")))

        (try-readonly (noescape "\"$HOME/.config/direnv\""))

        (try-rw-bind (noescape "\"$HOME/.cache/nix\"") (noescape "~/.cache/nix"))
        (try-rw-bind (noescape "\"$HOME/.npm\"") (noescape "~/.npm"))
        (try-rw-bind (noescape "\"$HOME/.bun\"") (noescape "~/.bun"))
        (try-rw-bind (noescape "\"$HOME/.cargo/registry\"") (noescape "~/.cargo/registry"))
        (try-rw-bind (noescape "\"$HOME/.cargo/git\"") (noescape "~/.cargo/git"))
        (try-rw-bind (noescape "\"$HOME/.local/share/direnv\"") (noescape "~/.local/share/direnv"))
        (try-rw-bind (noescape "\"$HOME/.local/share/rtk\"") (noescape "~/.local/share/rtk"))
      ]
      ++ extra jail.combinators
      ++ [
        (add-cleanup ''
          if [ -n "''${HERDR_RELAY_PID:-}" ]; then
            kill "$HERDR_RELAY_PID" 2>/dev/null || true
            wait "$HERDR_RELAY_PID" 2>/dev/null || true
          fi
          if [ -n "''${herdr_relay_dir:-}" ]; then
            ${lib.getExe' pkgs.coreutils "rm"} -f "$herdr_relay_dir/relay.sock"
            ${lib.getExe' pkgs.coreutils "rmdir"} "$herdr_relay_dir" 2>/dev/null || true
          fi
        '')
        (add-runtime ''
          RUNTIME_ARGS+=(--unsetenv GPG_TTY)
          if [ "''${HERDR_ENV:-}" = 1 ]; then
            if [ -z "''${HERDR_PANE_ID:-}" ] \
              || [[ "''${HERDR_SOCKET_PATH:-}" != /* ]] \
              || [ ! -S "$HERDR_SOCKET_PATH" ]; then
              echo "herdr relay: missing pane ID or absolute live socket path" >&2
              exit 1
            fi
            herdr_upstream=$(realpath "$HERDR_SOCKET_PATH")
            herdr_socket_parent=$(dirname "$herdr_upstream")
            herdr_cwd=$(realpath "$PWD")
            for mounted in "$herdr_cwd" "''${git_common:-}"; do
              [ -n "$mounted" ] || continue
              mounted=$(realpath "$mounted")
              if [ "$mounted" = / ] || [ "$herdr_socket_parent" = "$mounted" ] \
                || [[ "$herdr_socket_parent" == "$mounted/"* ]]; then
                echo "herdr relay: refusing a working tree containing the Herdr socket directory" >&2
                exit 1
              fi
            done

            herdr_relay_dir=$(mktemp -d /tmp/agent-herdr-relay.XXXXXXXX)
            ${lib.getExe herdrRelay} \
              --listen "$herdr_relay_dir/relay.sock" \
              --upstream "$herdr_upstream" \
              --pane-id "$HERDR_PANE_ID" --agent ${lib.escapeShellArg name} \
              > "$jail_state/log/herdr-relay-$$.log" 2>&1 &
            HERDR_RELAY_PID=$!
            herdr_relay_up=
            for _ in $(seq 1 100); do
              kill -0 "$HERDR_RELAY_PID" 2>/dev/null || break
              if [ -S "$herdr_relay_dir/relay.sock" ]; then
                herdr_relay_up=1
                break
              fi
              sleep 0.05
            done
            if [ -z "$herdr_relay_up" ]; then
              echo "herdr relay: failed to start; see $jail_state/log/herdr-relay-$$.log" >&2
              exit 1
            fi

            # Mount last so a caller's state/config overlay cannot expose the real socket.
            RUNTIME_ARGS+=(--bind "$herdr_relay_dir/relay.sock" "$HERDR_SOCKET_PATH")
            if [ "$herdr_upstream" != "$HERDR_SOCKET_PATH" ]; then
              RUNTIME_ARGS+=(--bind "$herdr_relay_dir/relay.sock" "$herdr_upstream")
            fi
          else
            RUNTIME_ARGS+=(--unsetenv HERDR_SOCKET_PATH)
          fi
        '')
      ]
  )

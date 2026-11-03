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

  hostQuery = pkgs.callPackage ./_host-query {};
  herdrRelay = pkgs.callPackage ./_herdr-relay {};
  herdrCore = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr-core;
  coreClient = pkgs.writeShellScriptBin "hc" ''
    # A worker must not inherit its launcher's host-sidebar identity.
    unset HERDR_ACTIVITY_SOCKET
    export XDG_RUNTIME_DIR=/tmp/agent-core/runtime
    export XDG_STATE_HOME=/tmp/agent-core/state
    export XDG_CONFIG_HOME=/tmp/agent-core/config
    exec ${lib.getExe herdrCore} "$@"
  '';

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

          # Bound only into this jail.
          host_query_dir=$(mktemp -d /tmp/agent-host-query.XXXXXXXX)
          host_query_sock="$host_query_dir/host-query.sock"

          # Not bound into the jail: host_ssh_agent relays it on approval.
          HOST_SSH_AUTH_SOCK="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gnupg/S.gpg-agent.ssh" \
            ${lib.getExe hostQuery} "$host_query_sock" "$grant_root" \
            > "$jail_state/log/host-query.log" 2>&1 &
          HOST_QUERY_PID=$!

          host_query_up=
          for _ in $(seq 1 20); do
            if [ -S "$host_query_sock" ]; then
              host_query_up=1
              break
            fi
            sleep 0.25
          done
          if [ -n "$host_query_up" ]; then
            RUNTIME_ARGS+=(--bind "$host_query_sock" /tmp/host-query.sock)
          else
            echo "${name}-jail: warning: host-query did not start on $host_query_sock" >&2
            echo "  host_exec / host_mount / host_journal / host_ssh_agent will be unavailable;" >&2
            echo "  see $jail_state/log/host-query.log" >&2
          fi

          RUNTIME_ARGS+=(
            --bind "$grant_root" "$HOME/granted"
            # Read-only: the log is the first thing to check when a host_*
            # tool misbehaves, and it is unreachable if only grants/ is bound.
            --ro-bind "$jail_state/log" "$jail_state/log"
            --setenv HOST_QUERY_SOCKET /tmp/host-query.sock
            # The inherited host value points at a socket the jail cannot see.
            --unsetenv SSH_AUTH_SOCK
          )
        '')
        (add-cleanup ''
          kill "''${HOST_QUERY_PID:-}" 2>/dev/null || true
          if [ -n "''${host_query_dir:-}" ]; then
            ${lib.getExe' pkgs.coreutils "rm"} -f "$host_query_dir/host-query.sock"
            ${lib.getExe' pkgs.coreutils "rmdir"} "$host_query_dir" 2>/dev/null || true
          fi
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

        (defer (set-env "PATH" (noescape "\"${rmSafe}/bin:${coreClient}/bin:$PATH\"")))

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
          if [ -n "''${APP_PROXY_PID:-}" ]; then
            kill "$APP_PROXY_PID" 2>/dev/null || true
            wait "$APP_PROXY_PID" 2>/dev/null || true
          fi
          if [ -n "''${app_proxy_dir:-}" ]; then
            ${lib.getExe' pkgs.coreutils "rm"} -f "$app_proxy_dir/app.sock"
            ${lib.getExe' pkgs.coreutils "rmdir"} "$app_proxy_dir" 2>/dev/null || true
          fi
          if [ -n "''${core_runtime_dir:-}" ]; then
            ${lib.getExe' pkgs.coreutils "rm"} -rf -- "$core_runtime_dir"
          fi
          if [ -n "''${CORE_ACTIVITY_PID:-}" ]; then
            kill "$CORE_ACTIVITY_PID" 2>/dev/null || true
            wait "$CORE_ACTIVITY_PID" 2>/dev/null || true
          fi
          if [ -n "''${core_activity_dir:-}" ]; then
            ${lib.getExe' pkgs.coreutils "rm"} -f "$core_activity_dir/report.sock"
            ${lib.getExe' pkgs.coreutils "rmdir"} "$core_activity_dir" 2>/dev/null || true
          fi
        '')
        (add-runtime ''
          RUNTIME_ARGS+=(--unsetenv GPG_TTY --unsetenv HERDR_ENV --unsetenv HERDR_PANE_ID --unsetenv HERDR_SOCKET_PATH)
          if [ -n "''${HC_TERMINAL_ID:-}" ]; then
            if [[ "''${HC_TERMINAL_SOCKET:-}" != /* ]] || [ ! -S "$HC_TERMINAL_SOCKET" ]; then
              echo "Core activity: missing absolute live terminal socket" >&2
              exit 1
            fi
            core_upstream=$(realpath "$HC_TERMINAL_SOCKET")
            core_socket_parent=$(dirname "$core_upstream")
            for mounted in "$PWD" "''${git_common:-}"; do
              [ -n "$mounted" ] || continue
              mounted=$(realpath "$mounted")
              if [ "$mounted" = / ] || [ "$core_socket_parent" = "$mounted" ] \
                || [[ "$core_socket_parent" == "$mounted/"* ]]; then
                echo "Core activity: refusing a working tree containing the Core socket directory" >&2
                exit 1
              fi
            done
            core_activity_dir=$(mktemp -d /tmp/agent-core-activity.XXXXXXXX)
            core_lock_dir="''${XDG_RUNTIME_DIR:-/tmp}/agent-core-activity-$(id -u)"
            (umask 077; mkdir -p "$core_lock_dir")
            core_lock=$(printf '%s\n%s' "$core_upstream" "$HC_TERMINAL_ID" | ${lib.getExe' pkgs.coreutils "sha256sum"})
            core_lock="''${core_lock%% *}"
            ${lib.getExe herdrRelay} \
              --listen "$core_activity_dir/report.sock" --upstream "$core_upstream" \
              --terminal "$HC_TERMINAL_ID" --agent ${lib.escapeShellArg name} \
              --lock-file "$core_lock_dir/$core_lock.lock" \
              > "$jail_state/log/core-activity-$$.log" 2>&1 &
            CORE_ACTIVITY_PID=$!
            for _ in $(seq 1 100); do
              kill -0 "$CORE_ACTIVITY_PID" 2>/dev/null || break
              [ -S "$core_activity_dir/report.sock" ] && break
              sleep 0.05
            done
            if [ ! -S "$core_activity_dir/report.sock" ]; then
              echo "Core activity: failed to start; see $jail_state/log/core-activity-$$.log" >&2
              exit 1
            fi
            # A read-only socket bind would still grant control; replace every inherited route.
            RUNTIME_ARGS+=(
              --ro-bind "$core_activity_dir/report.sock" /tmp/herdr-activity.sock
              --ro-bind "$core_activity_dir/report.sock" "$HC_TERMINAL_SOCKET"
              --ro-bind "$core_activity_dir/report.sock" "$core_upstream"
              --setenv HERDR_ACTIVITY_SOCKET /tmp/herdr-activity.sock
            )
          else
            RUNTIME_ARGS+=(--unsetenv HERDR_ACTIVITY_SOCKET)
          fi

          core_runtime_dir=$(mktemp -d /tmp/agent-core.XXXXXXXX)
          app_home="''${HERDR_APP_HOME:-''${XDG_CONFIG_HOME:-$HOME/.config}/herdr-app}"
          app_home=$(realpath -m "$app_home")
          for mounted in "$PWD" "''${git_common:-}"; do
            [ -n "$mounted" ] || continue
            mounted=$(realpath "$mounted")
            for protected in "$app_home" "/run/user/$(id -u)" "$core_runtime_dir"; do
              protected=$(realpath -m "$protected")
              if [ "$mounted" = / ] || [ "$protected" = "$mounted" ] \
                || [[ "$protected" == "$mounted/"* ]] || [[ "$mounted" == "$protected/"* ]]; then
                echo "${name}-jail: refusing a working tree overlapping host App or runtime state" >&2
                exit 1
              fi
            done
          done
          # Core autostarts inside this PID namespace, never through the host user manager.
          RUNTIME_ARGS+=(
            --bind "$core_runtime_dir" /tmp/agent-core
            --tmpfs "$app_home"
            --setenv HC_SOCKET /tmp/agent-core/runtime/herdr-core/agent.sock
            --setenv HC_SESSION agent
            --unsetenv HC_TERMINAL_ID --unsetenv HC_TERMINAL_SOCKET
            --setenv HERDR_SANDBOX_SOCKET "$core_runtime_dir/runtime/herdr-core/agent.sock"
          )

          # The App socket would run any program on the host; the jail gets a proxy
          # that starts programs in its own Core and shows them through herdr-core-view.
          app_proxy_dir=$(mktemp -d /tmp/agent-app-proxy.XXXXXXXX)
          ${lib.getExe' herdrRelay "agent-herdr-app-proxy"} \
            --listen "$app_proxy_dir/app.sock" --upstream "$app_home/herdr-app.sock" \
            --core "$core_runtime_dir/runtime/herdr-core/agent.sock" --workspace "$(realpath "$PWD")" \
            > "$jail_state/log/app-proxy-$$.log" 2>&1 &
          APP_PROXY_PID=$!
          for _ in $(seq 1 100); do
            kill -0 "$APP_PROXY_PID" 2>/dev/null || break
            [ -S "$app_proxy_dir/app.sock" ] && break
            sleep 0.05
          done
          if [ -S "$app_proxy_dir/app.sock" ]; then
            RUNTIME_ARGS+=(--bind "$app_proxy_dir/app.sock" "$app_home/herdr-app.sock")
          else
            echo "${name}-jail: warning: App proxy did not start; see $jail_state/log/app-proxy-$$.log" >&2
          fi
        '')
      ]
  )

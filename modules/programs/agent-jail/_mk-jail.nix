# Bubblewrap jail shared by every coding agent (omp, claude).
#
# Usage: import ./_mk-jail.nix {inherit inputs lib pkgs config;} {
#   name    = "claude";        # installed binary name, and the state dir prefix
#   package = pkgs.claude-code;
#   pre     = c: [ ... ];      # combinators that run before host-query starts
#   extra   = c: [ ... ];      # agent-specific binds and env
#   reportActivity = true;     # sidebar metadata bridge; harnesses only
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
  reportActivity ? true,
}: let
  jail = inputs.jail-nix.lib.extend {
    inherit pkgs;
    suppressExperimentalWarnings = true;
  };

  inherit (config.home) username;

  git = lib.getExe pkgs.git;

  fontsConf = pkgs.makeFontsConf {
    fontDirectories = [pkgs.dejavu_fonts];
    impureFontDirectories = [];
    includes = ["${pkgs.fontconfig.out}/etc/fonts/conf.d"];
  };

  hostQuery = pkgs.callPackage ./_host-query {};
  herdrRelay = pkgs.callPackage ./_herdr-relay {};

  # Signing and push grant: the agent key's public half, registered on GitHub as an
  # authentication and a signing key. The private half is the sops secret agent_ssh_key.
  agentPubFile = ./agent-ssh-key.pub;
  agentPub =
    if builtins.pathExists agentPubFile
    then lib.removeSuffix "\n" (builtins.readFile agentPubFile)
    else null;
  agentKey = lib.escapeShellArg (config.sops.secrets.agent_ssh_key.path or "");
  # Lets `git verify-commit` check agent-key signatures before a push.
  agentSigners = pkgs.writeText "agent-allowed-signers" ''
    ${config.programs.git.settings.user.email or ""} ${toString agentPub}
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
        (set-env "FONTCONFIG_FILE" fontsConf)
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
          if [ -n "''${AGENT_JAIL:-}" ]; then
            echo "${name}: already inside the $AGENT_JAIL jail; start it on the host instead:" >&2
            echo "  hc run -- ${name} ..." >&2
            exit 1
          fi
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
        (set-env "AGENT_JAIL" name)
        (add-runtime ''
          jail_state="$HOME/.local/share/${name}-jail"
          mkdir -p "$jail_state/log"
        '')
        (add-runtime ''
          grant_root="$jail_state/grants/$$"
          mkdir -p "$grant_root"

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
        # The user grants signing and push at launch (AGENT_JAIL_SIGNING=1). The key
        # stays in a host ssh-agent: the jail can use it, never read it.
        (add-runtime ''
          if [ -n "''${AGENT_JAIL_SIGNING:-}" ]; then
            if ${lib.boolToString (agentPub == null)} || [ ! -r ${agentKey} ]; then
              echo "${name}-jail: warning: signing grant requested, but the agent key is not set up" >&2
            else
              agent_key_dir=$(mktemp -d /tmp/agent-key.XXXXXXXX)
              ${lib.getExe' pkgs.openssh "ssh-agent"} -D -a "$agent_key_dir/agent.sock" \
                > "$jail_state/log/agent-key-$$.log" 2>&1 &
              AGENT_KEY_PID=$!
              for _ in $(seq 1 100); do
                [ -S "$agent_key_dir/agent.sock" ] && break
                sleep 0.05
              done
              if SSH_AUTH_SOCK="$agent_key_dir/agent.sock" ${lib.getExe' pkgs.openssh "ssh-add"} -q ${agentKey} \
                >> "$jail_state/log/agent-key-$$.log" 2>&1; then
                RUNTIME_ARGS+=(
                  --bind "$agent_key_dir/agent.sock" /tmp/agent-ssh.sock
                  --setenv SSH_AUTH_SOCK /tmp/agent-ssh.sock
                  # Command-line scope: overrides the GPG signing in the read-only git config.
                  --setenv GIT_CONFIG_COUNT 3
                  --setenv GIT_CONFIG_KEY_0 gpg.format --setenv GIT_CONFIG_VALUE_0 ssh
                  --setenv GIT_CONFIG_KEY_1 user.signingkey
                  --setenv GIT_CONFIG_VALUE_1 ${lib.escapeShellArg "key::${toString agentPub}"}
                  --setenv GIT_CONFIG_KEY_2 gpg.ssh.allowedSignersFile --setenv GIT_CONFIG_VALUE_2 ${agentSigners}
                )
              else
                echo "${name}-jail: warning: could not load the agent key; see $jail_state/log/agent-key-$$.log" >&2
              fi
            fi
          fi
        '')
        (add-cleanup ''
          if [ -n "''${AGENT_KEY_PID:-}" ]; then
            kill "$AGENT_KEY_PID" 2>/dev/null || true
          fi
          if [ -n "''${agent_key_dir:-}" ]; then
            ${lib.getExe' pkgs.coreutils "rm"} -f "$agent_key_dir/agent.sock"
            ${lib.getExe' pkgs.coreutils "rmdir"} "$agent_key_dir" 2>/dev/null || true
          fi
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
          if ${lib.boolToString reportActivity} && [ -n "''${HC_TERMINAL_ID:-}" ]; then
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
            RUNTIME_ARGS+=(
              --ro-bind "$core_activity_dir/report.sock" /tmp/herdr-activity.sock
              --setenv HERDR_ACTIVITY_SOCKET /tmp/herdr-activity.sock
            )
          else
            RUNTIME_ARGS+=(--unsetenv HERDR_ACTIVITY_SOCKET)
          fi

          app_home="''${HERDR_APP_HOME:-''${XDG_CONFIG_HOME:-$HOME/.config}/herdr-app}"
          app_home=$(realpath -m "$app_home")
          for mounted in "$PWD" "''${git_common:-}"; do
            [ -n "$mounted" ] || continue
            mounted=$(realpath "$mounted")
            for protected in "$app_home" "/run/user/$(id -u)"; do
              protected=$(realpath -m "$protected")
              if [ "$mounted" = / ] || [ "$protected" = "$mounted" ] \
                || [[ "$protected" == "$mounted/"* ]] || [[ "$mounted" == "$protected/"* ]]; then
                echo "${name}-jail: refusing a working tree overlapping host App or runtime state" >&2
                exit 1
              fi
            done
          done
          # The user's own Core and App, unrestricted: whatever they start runs on the host,
          # outside this jail. Directories, not socket inodes, because both recreate their
          # sockets on restart; read-only, so a jailed `hc` cannot autostart a Core of its own
          # in the host's place.
          core_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/herdr-core"
          (umask 077; mkdir -p "$core_dir" "$app_home")
          RUNTIME_ARGS+=(--ro-bind "$core_dir" "$core_dir" --ro-bind "$app_home" "$app_home")
          if [[ "''${HC_TERMINAL_SOCKET:-}" == /* ]]; then
            terminal_core_dir=$(dirname "$(realpath -m "$HC_TERMINAL_SOCKET")")
            if [ "$terminal_core_dir" != "$(realpath -m "$core_dir")" ] && [ -d "$terminal_core_dir" ]; then
              RUNTIME_ARGS+=(--ro-bind "$terminal_core_dir" "$terminal_core_dir")
            fi
          fi
        '')
      ]
  )

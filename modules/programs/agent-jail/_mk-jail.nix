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
  herdrCore = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr-core;
  # Connects the jail Core's `host` machine to the host link bound into the jail.
  hostVia = pkgs.writeShellScript "agent-host-via" ''
    # Core passes the remote shell line as the last argument; the link picks the upstream itself.
    exec ${lib.getExe pkgs.socat} - UNIX-CONNECT:/tmp/agent-host-link.sock
  '';
  coreClient = pkgs.writeShellScriptBin "hc" ''
    # A worker must not inherit its launcher's host-sidebar identity.
    unset HERDR_ACTIVITY_SOCKET
    export XDG_RUNTIME_DIR=/tmp/agent-core/runtime
    export XDG_STATE_HOME=/tmp/agent-core/state
    export XDG_CONFIG_HOME=/tmp/agent-core/config
    # Register the host link once per session; the directory doubles as the lock.
    if [ -S /tmp/agent-host-link.sock ] && mkdir /tmp/agent-core/host-machine 2>/dev/null; then
      ${lib.getExe' herdrCore "herdr-core"} machine add --via ${hostVia} --name host --temp >/dev/null 2>&1 \
        || ${lib.getExe' pkgs.coreutils "rmdir"} /tmp/agent-core/host-machine
    fi
    exec ${lib.getExe herdrCore} "$@"
  '';
  # Jail wrappers the host link starts on the host, installed by the harness modules.
  userBin = "/etc/profiles/per-user/${username}/bin";

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
            echo "  hc run --on host -- ${name} ..." >&2
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
          # The host link starts everything at the workspace root; the subdirectory is
          # applied inside the jail so a planted symlink cannot point the bind elsewhere.
          if [ -n "''${AGENT_JAIL_CHDIR:-}" ]; then
            RUNTIME_ARGS+=(--chdir "$PWD/$AGENT_JAIL_CHDIR" --setenv PWD "$PWD/$AGENT_JAIL_CHDIR" --unsetenv AGENT_JAIL_CHDIR)
          fi
        '')
        # A jail another agent started on the host gets no host-query: its parent could
        # otherwise type the answer to its host_* approval prompts.
        (add-runtime ''
          if [ -z "''${AGENT_JAIL_NO_HOST:-}" ]; then
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
          else
            RUNTIME_ARGS+=(--unsetenv HOST_QUERY_SOCKET --unsetenv SSH_AUTH_SOCK)
          fi
        '')
        # The user grants signing and push at launch (AGENT_JAIL_SIGNING=1); a granted
        # session passes it to host children it labels agent-jail.signing=1. The key stays
        # in a host ssh-agent: the jail can use it, never read it.
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
                agent_signing=1
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
          if [ -n "''${HOST_LINK_PID:-}" ]; then
            kill "$HOST_LINK_PID" 2>/dev/null || true
            wait "$HOST_LINK_PID" 2>/dev/null || true
          fi
          if [ -n "''${host_link_dir:-}" ]; then
            ${lib.getExe' pkgs.coreutils "rm"} -f "$host_link_dir/link.sock"
            ${lib.getExe' pkgs.coreutils "rmdir"} "$host_link_dir" 2>/dev/null || true
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

          # The host Core as the jail Core's `host` machine; everything it starts is jailed.
          host_link_dir=$(mktemp -d /tmp/agent-host-link.XXXXXXXX)
          ${lib.getExe' herdrRelay "agent-herdr-host-link"} \
            --listen "$host_link_dir/link.sock" \
            --core "$core_runtime_dir/runtime/herdr-core/agent.sock" --workspace "$(realpath "$PWD")" \
            --parent "''${HC_TERMINAL_ID:-}" --runner ${userBin}/agent-jail-run \
            --wrapper claude=${userBin}/claude --wrapper omp=${userBin}/omp \
            ''${agent_signing:+--signing} \
            -- ${lib.getExe' herdrCore "herdr-core"} connect \
            > "$jail_state/log/host-link-$$.log" 2>&1 &
          HOST_LINK_PID=$!
          for _ in $(seq 1 100); do
            kill -0 "$HOST_LINK_PID" 2>/dev/null || break
            [ -S "$host_link_dir/link.sock" ] && break
            sleep 0.05
          done
          if [ -S "$host_link_dir/link.sock" ]; then
            RUNTIME_ARGS+=(--bind "$host_link_dir/link.sock" /tmp/agent-host-link.sock)
          else
            echo "${name}-jail: warning: host link did not start; see $jail_state/log/host-link-$$.log" >&2
          fi
        '')
      ]
  )

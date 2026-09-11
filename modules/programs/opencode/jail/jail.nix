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
        # overlay-tmp is flagged experimental upstream; it is the only way to
        # hand opencode a config dir it can write into without persisting.
        suppressExperimentalWarnings = true;
      };

      inherit (config.home) username;

      git = lib.getExe pkgs.git;
      curl = lib.getExe pkgs.curl;

      hostQuery = pkgs.callPackage ./_host-query {};

      # Deletions land in the FreeDesktop trash instead of being destroyed.
      # Installed via `defer` so it prepends to PATH after the base coreutils.
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

      # Additive config layer, merged after the user's real ~/.config/opencode.
      # Used only for the sandbox instructions file, so nothing here conflicts
      # with the global config.
      jailConfig = pkgs.writeTextDir "opencode.json" (builtins.toJSON {
        "$schema" = "https://opencode.ai/config.json";
        instructions = ["${./jail-context.md}"];
      });

      # pkgs.opencode rather than config.programs.opencode.package: that option
      # is set to null on Linux so the module installs no binary of its own and
      # this jail owns the name `opencode`. Reading it here would be a cycle.
      jailed = jail "opencode" pkgs.opencode (
        with jail.combinators; [
          # jail-nix's `base` ends with --clearenv and then re-exports three
          # variables. We want the host environment intact: direnv applies
          # itself in the launching shell and reaches the jail by inheritance,
          # exactly as it does for unjailed opencode. So rebuild base's pieces
          # without that step.
          reset
          (unsafe-add-raw-args "--proc /proc")
          (unsafe-add-raw-args "--dev /dev")
          (unsafe-add-raw-args "--tmpfs /tmp")
          (unsafe-add-raw-args "--tmpfs ~")
          (ro-bind "${pkgs.bash}/bin/sh" "/bin/sh")
          fake-passwd
          # No SSH agent is bound. Drop the pointer to it so ssh reports "no
          # agent" rather than failing against a socket that is not there.
          (unsafe-add-raw-args "--unsetenv SSH_AUTH_SOCK")

          network
          # opencode is a TUI, so it needs the controlling terminal. Safe here:
          # dev.tty.legacy_tiocsti is 0, which is what --new-session guards.
          no-new-session

          (ro-bind "/nix/store" "/nix/store")
          # bwrap's uid map makes the store look user-owned, which trips nix
          # into single-user mode; the daemon is what actually has write access.
          (set-env "NIX_REMOTE" "daemon")
          (try-rw-bind "/nix/var/nix/daemon-socket" "/nix/var/nix/daemon-socket")
          (try-readonly "/nix/var/nix/db")
          # Unbound, nix-info exits 1 looking for profiles/per-user.
          (try-readonly "/nix/var/nix/profiles")
          (try-readonly "/etc/nix")
          (try-readonly "/etc/static")

          # The host toolchain, rather than an enumerated toolbelt: every store
          # binary is reachable by absolute path anyway once /nix/store is bound,
          # so a curated PATH would be tidiness, not a boundary.
          (try-readonly "/run/current-system/sw")
          (try-readonly "/etc/profiles/per-user/${username}")

          # The jail root is a tmpfs with only /bin/sh, so `#!/usr/bin/env` dies.
          (ro-bind "${pkgs.coreutils}/bin/env" "/usr/bin/env")

          mount-cwd

          # A linked worktree's .git is a file pointing into the main checkout,
          # and git needs to write the index and reflogs there.
          (add-runtime ''
            if git_common=$(${git} rev-parse --git-common-dir 2>/dev/null) \
              && git_dir=$(${git} rev-parse --git-dir 2>/dev/null) \
              && [ "$git_common" != "$git_dir" ]; then
              git_common=$(realpath "$git_common")
              RUNTIME_ARGS+=(--bind "$git_common" "$git_common")
            fi
          '')

          # host-query runs on the host and is the jail's only route out.
          # The grant root is bound in rather than created inside, because a
          # bindfs mount made under it on the host propagates into the running
          # jail (/ is a shared mount) — that is what makes host_mount take
          # effect without a restart.
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

          # opencode writes into its own config dir on every start (a .gitignore,
          # and a background `bun add @opencode-ai/plugin`). The tmpfs upper layer
          # absorbs that and drops it at exit.
          (overlay-tmp [(noescape "\"$HOME/.config/opencode\"")] (noescape "~/.config/opencode"))
          (overlay-tmp ["${jailConfig}"] (noescape "~/.config/opencode-jail"))
          (set-env "OPENCODE_CONFIG_DIR" (noescape "\"$HOME/.config/opencode-jail\""))
          (try-rw-bind (noescape "\"$HOME/.local/share/opencode\"") (noescape "~/.local/share/opencode"))
          (try-rw-bind (noescape "\"$HOME/.local/state/opencode\"") (noescape "~/.local/state/opencode"))
          (try-rw-bind (noescape "\"$HOME/.cache/opencode\"") (noescape "~/.cache/opencode"))

          # Editor socket for the nvim MCP. rw because connect(2) needs write.
          (add-runtime ''
            nvim_sock="$HOME/.cache/nvim/server-''${HERDR_WORKSPACE_ID:-dettached}.pipe"
            if [ -S "$nvim_sock" ]; then
              RUNTIME_ARGS+=(--bind "$nvim_sock" "$nvim_sock")
            fi
          '')

          # No gpg-agent socket, deliberately. The agent is a signing and
          # decryption oracle: it would let the jail sign as the user and
          # decrypt every sops secret. signByDefault stays true in the
          # read-only git config, so `git commit` fails for want of a signer —
          # which is the intended gate. Committing goes through host_exec.
          (try-readonly (noescape "\"$HOME/.config/git\""))
          (try-readonly (noescape "\"$HOME/.config/gh\""))
          (set-env "GIT_CONFIG_COUNT" "1")
          (set-env "GIT_CONFIG_KEY_0" "core.sshCommand")
          (set-env "GIT_CONFIG_VALUE_0" "${gitSshDeny}")

          # Trash-backed deletion, prepended so it shadows coreutils' rm.
          # set-env rather than add-path: add-path builds on state.env.PATH,
          # which is empty now that base (and its --clearenv) is gone, so it
          # would replace the inherited PATH with just this one entry.
          #
          # The host's ~/.local/share/Trash is deliberately NOT bound. Every
          # writable path here is its own mount, so the freedesktop spec always
          # picks that mount's own .Trash-1000 — nothing could ever land in the
          # home trash, while binding it would expose the user's real deleted
          # files read-write for no gain.
          (defer (set-env "PATH" (noescape "\"${rmSafe}/bin:$PATH\"")))

          # nix-direnv reaches direnv through ~/.config/direnv/lib, not a
          # direnvrc, so bind the real directory rather than generating one.
          # Read-only, so the agent cannot disable it; `direnv allow` still
          # works because its state lives in ~/.local/share/direnv below.
          (try-readonly (noescape "\"$HOME/.config/direnv\""))

          (try-rw-bind (noescape "\"$HOME/.cache/nix\"") (noescape "~/.cache/nix"))
          (try-rw-bind (noescape "\"$HOME/.npm\"") (noescape "~/.npm"))
          # opencode re-runs `bun add @opencode-ai/plugin` every start; without
          # this the download is repeated into a tmpfs each session.
          (try-rw-bind (noescape "\"$HOME/.bun\"") (noescape "~/.bun"))
          (try-rw-bind (noescape "\"$HOME/.cargo/registry\"") (noescape "~/.cargo/registry"))
          (try-rw-bind (noescape "\"$HOME/.cargo/git\"") (noescape "~/.cargo/git"))
          (try-rw-bind (noescape "\"$HOME/.local/share/direnv\"") (noescape "~/.local/share/direnv"))

          # No env forwarding list: --clearenv is gone (see `reset` above), so
          # the host environment arrives whole. That covers the sops-derived
          # keys from env-secrets.fish, the HERDR_* identifiers, terminfo, and
          # anything direnv exported for the working directory.
        ]
      );
    in {
      home.packages = [jailed];
    };
  };
}

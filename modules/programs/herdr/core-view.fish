if test (count $argv) -ne 2
    echo 'usage: herdr-core-view SANDBOX_SOCKET TERMINAL' >&2
    exit 2
end
set -l socket (@realpath@ -- $argv[1]); or exit 1
if not string match -rq '^/tmp/agent-core\.[a-zA-Z0-9]{8}/runtime/herdr-core/agent\.sock$' -- "$socket"; or not test -S "$socket"
    echo 'herdr-core-view: expected a live agent sandbox socket' >&2
    exit 1
end
set -l term xterm-256color
if set -q TERM; and test -n "$TERM"
    set term "$TERM"
end
# Bind the socket inode, not its parent: attach cannot autostart a host Core.
exec @bwrap@ --unshare-all --die-with-parent \
    --ro-bind /nix/store /nix/store --proc /proc --dev /dev --tmpfs /tmp \
    --ro-bind "$socket" /core.sock --clearenv \
    --setenv HOME /tmp --setenv XDG_RUNTIME_DIR /tmp \
    --setenv HC_SOCKET /core.sock --setenv TERM "$term" \
    -- @core@ attach $argv[2]

if test (uname) = Darwin
    set -l _runtime_dir (getconf DARWIN_USER_TEMP_DIR 2>/dev/null | string trim)
    if test -n "$_runtime_dir" -a -f "$_runtime_dir/env-secrets.fish"
        source "$_runtime_dir/env-secrets.fish"
    end
else
    if test -n "$XDG_RUNTIME_DIR" -a -f "$XDG_RUNTIME_DIR/env-secrets.fish"
        source "$XDG_RUNTIME_DIR/env-secrets.fish"
    end
end

# Set SSH to use GPG agent
set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)

zoxide init fish | source

# Vi key bindings
fish_vi_key_bindings

# Starship transient prompt functions
function starship_transient_prompt_func
    echo \n
    string pad --right --width=$COLUMNS --char='.' "."
    echo "󰞷  "
end

function starship_transient_rprompt_func
    starship module time
end

# Initialize starship
starship init fish | source
enable_transience

# Opens a workspace for a directory, with the default layout:
#
#   tab "neovim"   -> nvim (70%) | opencode (30%)
#   tab "terminal" -> main (70%) | tooling (30%)
#
# usage: herdr-workspace [dir] [label]
#
# dir defaults to the calling pane's cwd. label defaults to <repo>/<checkout>
# for a main checkout ("integrations-mono/main" rather than a bare "main"), and
# to the bare directory name for a linked worktree, which the sidebar already
# nests under its repo.
#
# An existing workspace for the directory is reused: it is only laid out when
# it still has nothing but its root pane, so running this twice is harmless.
# An explicitly passed label renames the workspace even when it already exists.
# herdr is attached at the end unless we are already inside it.
#
# herdr panes are always interactive shells (pane create takes no argv), so
# `pane run` types into the shell and quitting nvim/opencode leaves the pane
# alive on a prompt.

set -l herdr $HERDR_BIN_PATH
test -z "$herdr"; and set herdr @herdr@

set -l dir $argv[1]
test -z "$dir"; and set dir $HERDR_ACTIVE_PANE_CWD
test -z "$dir"; and set dir $PWD

set -l label $argv[2]

# Keybindings export HERDR_ACTIVE_PANE_ID, pane processes HERDR_PANE_ID.
set -l attach 1
test -n "$HERDR_ENV$HERDR_PANE_ID$HERDR_ACTIVE_PANE_ID"; and set attach 0

function _herdr_server_running -a herdr
    $herdr status server 2>/dev/null | string match -q 'status: running'
end

# A bare directory name is useless for a main checkout kept as
# <repo>/<branch> — half of them would be called "main" — but it is exactly
# right for a linked worktree, which the sidebar nests under its repo anyway.
function _herdr_workspace_label -a dir
    set -l name (path basename $dir)

    set -l common (@git@ -C $dir rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
    if test -z "$common"
        echo $name
        return
    end

    set -l gitdir (@git@ -C $dir rev-parse --path-format=absolute --git-dir 2>/dev/null)
    if test "$gitdir" != "$common"
        echo $name
        return
    end

    set -l repo (@git@ -C $dir remote get-url origin 2>/dev/null \
        | path basename | string replace -r '\.git$' '')
    test -z "$repo"; and set repo (path basename (path dirname (path dirname $common)))

    if test "$repo" = "$name"
        echo $name
    else
        echo "$repo/$name"
    end
end

function _herdr_ready -a herdr pane
    # Give the freshly spawned shell time to draw a prompt before typing.
    $herdr pane wait-output $pane --regex '.' --timeout 3000 >/dev/null 2>&1
end

function _herdr_build_layout -a herdr workspace editor_tab editor_pane
    $herdr tab rename $editor_tab neovim >/dev/null
    # --ratio is the share kept by the pane being split, so 0.7 leaves the new pane on the right at 30%.
    set -l agent_pane ($herdr pane split --pane $editor_pane --direction right --ratio 0.7 --no-focus \
        | @jq@ -r '.result.pane.pane_id')

    $herdr pane rename $editor_pane neovim >/dev/null
    $herdr pane rename $agent_pane opencode >/dev/null

    set -l terminal ($herdr tab create --workspace $workspace --label terminal --no-focus \
        | @jq@ -r '.result.tab.tab_id, .result.root_pane.pane_id')
    set -l main_pane $terminal[2]
    set -l tooling_pane ($herdr pane split --pane $main_pane --direction right --ratio 0.7 --no-focus \
        | @jq@ -r '.result.pane.pane_id')

    $herdr pane rename $main_pane main >/dev/null
    $herdr pane rename $tooling_pane tooling >/dev/null

    _herdr_ready $herdr $editor_pane
    $herdr pane run $editor_pane nvim >/dev/null
    _herdr_ready $herdr $agent_pane
    $herdr pane run $agent_pane opencode >/dev/null
end

# Every command below needs a server; a bare `herdr` would attach instead of
# returning, so start it headless when nothing is up yet.
if not _herdr_server_running $herdr
    $herdr server >/dev/null 2>&1 &
    disown
    for attempt in (seq 50)
        _herdr_server_running $herdr; and break
        @sleep@ 0.1
    end
end

# Trust the environment before any pane shell starts, otherwise nvim and
# opencode come up without it. Repos without direnv are left alone.
if test -f $dir/.envrc
    @direnv@ allow $dir 2>/dev/null
end

# Workspaces do not report their cwd, panes do.
set -l existing ($herdr pane list \
    | @jq@ -r --arg cwd "$dir" 'first(.result.panes[] | select(.cwd == $cwd) | .workspace_id) // empty')

if test -n "$existing"
    $herdr workspace focus $existing >/dev/null
    # Only an explicit label renames: the derived one would fight a rename the
    # user made in the sidebar.
    test -n "$label"; and $herdr workspace rename $existing $label >/dev/null

    # A workspace that still only has its root pane has never been laid out.
    set -l shape ($herdr workspace get $existing \
        | @jq@ -r '.result.workspace.pane_count, .result.workspace.active_tab_id')
    if test "$shape[1]" = 1
        set -l root_pane ($herdr pane list --workspace $existing \
            | @jq@ -r '.result.panes[0].pane_id')
        _herdr_build_layout $herdr $existing $shape[2] $root_pane
    end
else
    test -z "$label"; and set label (_herdr_workspace_label $dir)
    set -l created ($herdr workspace create --cwd $dir --label $label --focus \
        | @jq@ -r '.result.workspace.workspace_id, .result.tab.tab_id, .result.root_pane.pane_id')
    _herdr_build_layout $herdr $created[1] $created[2] $created[3]
end

if test $attach -eq 1
    exec $herdr
end

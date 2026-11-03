# Opens or focuses a Herdr App space without changing its terminal arrangement.
#
# usage: herdr-workspace [dir] [label]
#
# The directory defaults to the calling shell's cwd. An explicit label also
# renames an existing space; a derived label never overrides the user's name.

set -l dir $argv[1]
test -z "$dir"; and set dir $PWD
set dir (path resolve -- $dir)
if not test -d "$dir"
    echo "herdr-workspace: not a directory: $dir" >&2
    exit 1
end
set -l label $argv[2]

# Distinguish main checkouts kept as <repo>/<branch>; linked worktrees use
# their directory name unless the caller supplies the full branch label.
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

# Trust the environment before the App starts a terminal in this directory.
if test -f $dir/.envrc
    @direnv@ allow $dir; or exit 1
end

if not @app@ status >/dev/null 2>&1
    @app@ >/dev/null 2>&1 &
    disown
end

# A live control socket does not mean Core's saved spaces have been restored.
set -l ready 0
for attempt in (@seq@ 50)
    if @app@ status 2>/dev/null | @jq@ -e '.local_layout_ready == true' >/dev/null
        set ready 1
        break
    end
    @sleep@ 0.1
end
if test $ready -ne 1
    echo 'herdr-workspace: local App layout did not become ready' >&2
    exit 1
end
set -l world (@app@ ls); or exit 1

# Remote spaces may use the same path but belong to another machine.
set -l existing (printf '%s\n' "$world" | @jq@ -r --arg cwd "$dir" \
    'first(.spaces[] | select(.folder == $cwd and .machine == null) | .id) // empty')
or exit 1

if test -n "$existing"
    @app@ do space.select --id $existing; or exit 1
    if test -n "$label"
        @app@ do space.rename --id $existing --name $label; or exit 1
    end
else
    test -z "$label"; and set label (_herdr_workspace_label $dir)
    @app@ do space.new --folder $dir --name $label; or exit 1
end

# Opens a worktree as a herdr workspace labelled after its branch, creating the
# checkout when needed — a sibling folder inside the repo folder, the same
# <repo folder>/<branch> convention as the `git wa` alias.
#
# An existing worktree is reused, an existing branch is checked out untouched,
# and a new branch is created from HEAD. The git calls are made here rather
# than through `git wa` so this keeps working when the alias changes.
#
# usage: herdr-worktree [branch]
#
# Without an argument it prompts, which is how prefix+shift+g uses it: a popup
# is the only custom command type that owns a terminal. With an argument it
# runs unattended, so it is also usable from a shell or a script.

set -l herdr $HERDR_BIN_PATH
test -z "$herdr"; and set herdr @herdr@

set -l start $HERDR_ACTIVE_PANE_CWD
test -z "$start"; and set start $PWD

set -l branch $argv[1]

# A popup closes the moment the command exits, so errors need a keypress to
# stay readable. A branch passed on the command line means nobody is watching.
set -g herdr_worktree_interactive 0
test -z "$branch"; and set -g herdr_worktree_interactive 1

function _herdr_worktree_fail -a message
    echo "herdr-worktree: $message" >&2
    if test $herdr_worktree_interactive -eq 1
        read -l -P 'press enter to close: ' dismissed
    end
    exit 1
end

set -l common (@git@ -C $start rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
test -z "$common"; and _herdr_worktree_fail "$start is not inside a git work tree"

# herdr refuses worktree actions from a linked worktree, so always address the
# repo's main checkout.
set -l main_checkout (path dirname $common)
set -l repo_folder (path dirname $main_checkout)

if test $herdr_worktree_interactive -eq 1
    read -P 'branch: ' branch
end

# Quoted so an empty branch stays one argument: `string trim --` with none
# would read stdin and hang.
set branch (string trim -- "$branch")
test -z "$branch"; and exit 0

function _herdr_worktree_for_branch -a start branch
    set -l candidate
    for line in (@git@ -C $start worktree list --porcelain)
        if string match -q 'worktree *' -- $line
            set candidate (string replace 'worktree ' '' -- $line)
        else if test "$line" = "branch refs/heads/$branch"
            echo $candidate
            return 0
        end
    end
    return 1
end

set -l checkout (_herdr_worktree_for_branch $start $branch)

if test -n "$checkout"
    # Already a worktree of this repo: reuse it instead of touching git.
    test -d $checkout
    or _herdr_worktree_fail "$checkout is registered but missing, run: git worktree prune"
else
    # Same path convention as the `git wa` alias, raw branch name and all.
    set -l target $repo_folder/$branch
    test -e $target
    and _herdr_worktree_fail "$target exists but is not a worktree of this repo, run: git worktree prune"

    if @git@ -C $start rev-parse --verify --quiet refs/heads/$branch >/dev/null
        # Existing branch: check it out untouched, never reset to HEAD.
        @git@ -C $start worktree add $target $branch
        or _herdr_worktree_fail "git worktree add $target $branch failed"
    else
        @git@ -C $start worktree add $target -b $branch
        or _herdr_worktree_fail "git worktree add $target -b $branch failed"
    end

    # Trust git's own view of where the checkout landed, not the formula.
    set checkout (_herdr_worktree_for_branch $start $branch)
    test -n "$checkout"
    or _herdr_worktree_fail "could not locate the new checkout for $branch"
end

# Trust the environment before herdr spawns the workspace's first shell.
if test -f $checkout/.envrc
    @direnv@ allow $checkout 2>/dev/null
end

# The sidebar nests worktree workspaces under their repo, so the branch name
# alone is enough. Passed explicitly rather than left to herdr's auto-label,
# which would use the checkout's directory name and lose the "feature/" in a
# slashed branch.
$herdr worktree open --cwd $main_checkout --path $checkout --label $branch --focus >/dev/null
or _herdr_worktree_fail "herdr could not open $checkout"

@workspace@ $checkout $branch

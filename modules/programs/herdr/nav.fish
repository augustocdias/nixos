# herdr side of the vim-aware pane navigation. Bound to ctrl+h/j/k/l.
#
# When the focused pane runs vim/neovim in the foreground, hand the chord to
# that pane so vim moves between its own splits; the editor calls back into
# `herdr pane focus` when it hits a split edge. Any other foreground process
# moves herdr's pane focus directly.

set -l dir $argv[1]

set -l herdr $HERDR_BIN_PATH
test -z "$herdr"; and set herdr @herdr@

set -l pane $HERDR_ACTIVE_PANE_ID
test -z "$pane"; and set pane $HERDR_PANE_ID
test -z "$pane"; and exit 0

switch $dir
    case left
        set -f key ctrl+h
    case down
        set -f key ctrl+j
    case up
        set -f key ctrl+k
    case right
        set -f key ctrl+l
    case '*'
        echo "herdr-nav: unknown direction: $dir" >&2
        exit 2
end

# Same matcher vim-tmux-navigator uses: vi, vim, nvim, view, gvim, *diff.
set -l foreground ($herdr pane process-info --pane $pane | @jq@ -r '.result.process_info.foreground_processes[]?.name // empty')

if string match -qir '^g?(view|l?n?vim?x?)(diff)?$' -- $foreground
    exec $herdr pane send-keys $pane $key
else
    exec $herdr pane focus --direction $dir --pane $pane
end

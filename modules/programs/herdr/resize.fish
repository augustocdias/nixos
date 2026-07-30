# herdr has no direct resize action, only an interactive resize mode, so
# ctrl+alt+h/j/k/l go through the CLI instead. Bound as a shell keybinding.

set -l dir $argv[1]

set -l herdr $HERDR_BIN_PATH
test -z "$herdr"; and set herdr @herdr@

set -l pane $HERDR_ACTIVE_PANE_ID
test -z "$pane"; and set pane $HERDR_PANE_ID
test -z "$pane"; and exit 0

switch $dir
    case left down up right
        exec $herdr pane resize --direction $dir --pane $pane
    case '*'
        echo "herdr-resize: unknown direction: $dir" >&2
        exit 2
end

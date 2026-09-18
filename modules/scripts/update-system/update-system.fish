#!/usr/bin/env fish
# Update all system components: flake inputs, extensions

set -l RED '\033[0;31m'
set -l GREEN '\033[0;32m'
set -l BLUE '\033[0;34m'
set -l YELLOW '\033[0;33m'
set -l NC '\033[0m'

function run
    $argv
    or begin
        echo -e $RED"Command failed: $argv"$NC
        exit 1
    end
end

set -l show_help false
set -l skip_pins false

for arg in $argv
    switch $arg
        case -h --help
            set show_help true
        case --skip-pins
            set skip_pins true
        case '*'
            echo -e $RED"Unknown option: $arg"$NC
            set show_help true
    end
end

if test $show_help = true
    echo "Usage: update-system [options]"
    echo ""
    echo "Update all system components:"
    echo "  - Nix flake inputs (including neovim plugins)"
    echo "  - Hand-pinned Home Assistant sources (packages.hass-*)"
    echo "  - Firefox extensions (if installed)"
    echo "  - Thunderbird extensions (if installed)"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "      --skip-pins  Skip the Home Assistant pins (each one is built)"
    exit 0
end

echo -e $BLUE"══════════════════════════════════════════"$NC
echo -e $BLUE"       System Update"$NC
echo -e $BLUE"══════════════════════════════════════════"$NC
echo ""

echo -e $YELLOW"[1/4] Updating flake inputs..."$NC
run nix run ~/nixos#write-flake
run nix flake update --flake ~/nixos
echo ""

# The Home Assistant components/cards/themes are pinned by hand with their own
# hashes (nothing HACS-like watches them any more), so nix-update queries each
# upstream and rewrites version + hash in place. Failures are per-package and
# non-fatal: a GitHub rate-limit on one card should not abort the whole run.
echo -e $YELLOW"[2/4] Updating Home Assistant pins..."$NC
set -l pin_failures
if test $skip_pins = true
    echo -e $YELLOW"  skipped (--skip-pins)"$NC
else if not command -v nix-update >/dev/null
    echo -e $YELLOW"  nix-update not available, skipping (it lives in the dev shell)"$NC
else
    set -l sys (nix eval --raw --impure --expr builtins.currentSystem)

    # One eval for the whole set. Each pin may carry, in passthru:
    #   updatePolicy       "stable" follows releases, "branch" follows HEAD
    #   updateFile         repo-relative path, when nix-update cannot find it
    #   updateVersionRegex to reject tags upstream publishes but we don't want
    set -l pins (nix eval --json ~/nixos#packages.$sys --apply '
        ps:
          builtins.listToAttrs (
            map (n: {
              name = n;
              value = {
                policy = ps.${n}.updatePolicy or "stable";
                file = ps.${n}.updateFile or "";
                regex = ps.${n}.updateVersionRegex or "";
              };
            }) (builtins.filter (n: builtins.match "hass-.*" n != null) (builtins.attrNames ps))
          )' | jq -r 'to_entries[] | "\(.key)\t\(.value.policy)\t\(.value.file)\t\(.value.regex)"')

    for line in $pins
        set -l fields (string split \t -- $line)
        set -l pin $fields[1]
        set -l policy $fields[2]
        set -l file $fields[3]
        set -l regex $fields[4]

        set -l extra
        if test -n "$file"
            set -a extra --override-filename "$HOME/nixos/$file"
        end
        if test -n "$regex"
            set -a extra --version-regex "$regex"
        end

        echo "  $pin ($policy)"
        # --build so a bump that no longer compiles fails here rather than at
        # the next nixos-rebuild.
        nix-update -f ~/nixos -F --build --version=$policy $extra $pin
        or set -a pin_failures $pin
    end

    if test (count $pin_failures) -gt 0
        echo -e $RED"  failed: $pin_failures"$NC
    end
end
echo ""

echo -e $YELLOW"[3/4] Updating Firefox extensions..."$NC
if command -v update-firefox >/dev/null
    run update-firefox
else
    echo -e $YELLOW"  update-firefox not installed on this system, skipping"$NC
end
echo ""

echo -e $YELLOW"[4/4] Updating Thunderbird extensions..."$NC
if command -v update-thunderbird >/dev/null
    run update-thunderbird
else
    echo -e $YELLOW"  update-thunderbird not installed on this system, skipping"$NC
end
echo ""

echo -e $GREEN"══════════════════════════════════════════"$NC
echo -e $GREEN"       All updates complete!"$NC
echo -e $GREEN"══════════════════════════════════════════"$NC

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

for arg in $argv
    switch $arg
        case -h --help
            set show_help true
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
    echo "  - Firefox extensions (if installed)"
    echo "  - Thunderbird extensions (if installed)"
    echo ""
    echo "Options:"
    echo "  -h, --help       Show this help message"
    exit 0
end

echo -e $BLUE"══════════════════════════════════════════"$NC
echo -e $BLUE"       System Update"$NC
echo -e $BLUE"══════════════════════════════════════════"$NC
echo ""

echo -e $YELLOW"[1/3] Updating flake inputs..."$NC
run nix flake update --flake ~/nixos
echo ""

echo -e $YELLOW"[2/3] Updating Firefox extensions..."$NC
if command -v update-firefox >/dev/null
    run update-firefox
else
    echo -e $YELLOW"  update-firefox not installed on this system, skipping"$NC
end
echo ""

echo -e $YELLOW"[3/3] Updating Thunderbird extensions..."$NC
if command -v update-thunderbird >/dev/null
    run update-thunderbird
else
    echo -e $YELLOW"  update-thunderbird not installed on this system, skipping"$NC
end
echo ""

echo -e $GREEN"══════════════════════════════════════════"$NC
echo -e $GREEN"       All updates complete!"$NC
echo -e $GREEN"══════════════════════════════════════════"$NC

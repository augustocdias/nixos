# Converges herdr's plugin registry with the nix-declared plugin set.
#
# argv is the list of built plugin directories. herdr owns
# ~/.config/herdr/plugins.json (it rewrites it on plugin enable/disable), so we
# only ever read it and mutate through `herdr plugin link|unlink`. Registry
# entries outside /nix/store are left alone: those were installed by hand.

set -l herdr @herdr@

set -l config_home $XDG_CONFIG_HOME
test -z "$config_home"; and set config_home $HOME/.config
set -l registry $config_home/herdr/plugins.json

set -l known_ids
set -l known_roots
if test -f $registry
    for entry in (@jq@ -r '.[] | "\(.plugin_id)\t\(.plugin_root)"' $registry 2>/dev/null)
        set -l fields (string split \t -- $entry)
        set -a known_ids $fields[1]
        set -a known_roots $fields[2]
    end
end

for root in $argv
    set -l id (cat $root/.herdr-plugin-id)
    set -l index (contains --index -- $id $known_ids; or true)

    if test -n "$index" -a "$known_roots[$index]" = "$root"
        continue
    end

    test -n "$index"; and $herdr plugin unlink $id >/dev/null
    $herdr plugin link $root >/dev/null
end

for index in (seq (count $known_ids))
    set -l id $known_ids[$index]
    set -l root $known_roots[$index]

    string match -q '/nix/store/*' -- $root; or continue
    contains -- $root $argv; and continue

    $herdr plugin unlink $id >/dev/null
end

# Translates opencode's jailed bash ruleset into Claude Code rule lists.
#
# Lossless only because the source is shaped "* = allow, specific overrides
# narrow toward ask/deny": opencode resolves by last match, Claude by
# deny > ask > allow, and both agree when every override is stricter than
# the default. An override that *widens* (an allow under a deny glob) would
# silently stop working here.
{baseBash}: let
  bash = pattern:
    if pattern == "*"
    then "Bash"
    else "Bash(${pattern})";
  pick = action:
    map bash (builtins.filter (k: baseBash.${k} == action) (builtins.attrNames baseBash));
in {
  allow = pick "allow";
  ask = pick "ask";
  deny = pick "deny";
}

# Translates the shared jailed bash ruleset (agent-shared/_bash.nix) into
# Claude Code rule lists.
#
# Lossless only because the source is shaped "* = allow, specific overrides
# narrow toward ask/deny": Claude resolves by deny > ask > allow. An override
# that *widens* (an allow under a deny glob) would silently stop working here.
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

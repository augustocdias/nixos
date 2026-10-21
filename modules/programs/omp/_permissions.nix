# omp approval settings, built from opencode's bash ruleset so all three
# harnesses share one source of truth.
#
# omp resolves `bash.patterns` by first match, so the rules are emitted
# strictest first: deny, then prompt, then allow. That matches opencode
# (last match) and Claude (deny > ask > allow) only because every override in
# the source narrows toward ask/deny — the same caveat as
# claude-code/_permissions.nix.
{
  lib,
  jailed,
}: let
  baseBash = (import ../opencode/_permissions.nix {inherit jailed;}).baseBash;

  rules = action: approval:
    map (match: {inherit match approval;})
    (builtins.filter (k: k != "*" && baseBash.${k} == action) (builtins.attrNames baseBash));
in {
  tools = {
    # Jailed: the sandbox is the boundary and unmatched bash runs, as with
    # opencode's `* = allow`. Darwin has no jail: edits pass, anything that
    # executes code (unmatched bash, eval, task, browser) asks.
    approvalMode =
      if jailed
      then "yolo"
      else "write";

    # Explicit prompts are enforced even in yolo and never offer "approve for
    # session". The work MCP servers are gated by extensions/gate.ts instead,
    # because these keys take no wildcards.
    approval = lib.optionalAttrs jailed {
      mcp__host_exec = "prompt";
      mcp__host_mount = "prompt";
      mcp__host_journal = "prompt";
    };
  };

  bash.patterns = rules "deny" "deny" ++ rules "ask" "prompt" ++ rules "allow" "allow";
}

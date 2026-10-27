# omp approval settings, built from the bash ruleset shared with Claude Code
# (agent-shared/_bash.nix).
#
# omp resolves `bash.patterns` by first match, so the rules are emitted
# strictest first: deny, then prompt, then allow. That matches Claude
# (deny > ask > allow) only because every override in the source narrows
# toward ask/deny.
{
  lib,
  jailed,
}: let
  baseBash = import ../agent-shared/_bash.nix {inherit jailed;};

  rules = action: approval:
    map (match: {inherit match approval;})
    (builtins.filter (k: k != "*" && baseBash.${k} == action) (builtins.attrNames baseBash));
in {
  tools = {
    # Jailed: the sandbox is the boundary and unmatched bash runs (`* = allow`).
    # Darwin has no jail: edits pass, anything that executes code (unmatched
    # bash, eval, task, browser) asks.
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
      mcp__host_ssh_agent = "prompt";
    };
  };

  bash.patterns = rules "deny" "deny" ++ rules "ask" "prompt" ++ rules "allow" "allow";
}

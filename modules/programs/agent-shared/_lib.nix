# Prompts shared by opencode and claude-code. The bodies are plain markdown
# without frontmatter; each harness adds its own via `withFrontmatter`, since
# the two disagree on keys (opencode: mode/agent/subtask, claude: name/tools).
{lib}: {
  description = {
    reviewer = "Read-only code reviewer for pre-commit and PR review. Inspects diffs for bugs, security issues, edge cases, and style violations. Cannot edit files. Invoke with @reviewer or via the /review command.";
    test-writer = "Writes and improves tests only — unit, integration, and edge-case coverage. Does not modify implementation code. Use when you want tests added for existing behavior or new code without touching the code under test.";
    commit = "Draft a commit message from staged changes and commit after approval";
    pr = "Draft a pull request description from the branch diff and open it after approval";
    review = "Review the current changes (uncommitted, or a branch/PR) with the reviewer subagent";
  };

  # JSON strings are valid YAML scalars, so values never need hand-quoting.
  withFrontmatter = fm: body:
    "---\n"
    + lib.concatLines (lib.mapAttrsToList (k: v: "${k}: ${builtins.toJSON v}") fm)
    + "---\n\n"
    + builtins.readFile body;

  agents = ./agents;
  commands = ./commands;
  skills = ./skills;
  context = ./context.md;
}

# Prompts shared by omp and claude-code. The bodies are plain markdown without
# frontmatter; each harness adds its own via `withFrontmatter`, since they
# disagree on keys.
{lib}: rec {
  description = {
    test-writer = "Writes and improves tests only — unit, integration, and edge-case coverage. Does not modify implementation code. Use when you want tests added for existing behavior or new code without touching the code under test.";
    commit = "Draft a commit message from staged changes and commit after approval";
  };

  # JSON strings are valid YAML scalars, so values never need hand-quoting.
  withFrontmatter = fm: body: withFrontmatterText fm (builtins.readFile body);

  withFrontmatterText = fm: text:
    "---\n"
    + lib.concatLines (lib.mapAttrsToList (k: v: "${k}: ${builtins.toJSON v}") fm)
    + "---\n\n"
    + text;

  agents = ./agents;
  commands = ./commands;
  skills = ./skills;
  context = ./context.md;
}

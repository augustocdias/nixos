{
  inputs,
  lib,
  ...
}: let
  models = import ./_models.nix;
  fallbacks = import ./_fallbacks.nix;
  # Bundled duplicates of house skills, and CLIs that would take over work the profile does itself.
  # git-conventions' ownership agreement does not apply: Hermes owns all Git work through its own `git` skill.
  # Bootstrap replaces this list, so a Desktop toggle lasts until the next restart.
  disabledSkills = ["test-driven-development" "systematic-debugging" "requesting-code-review" "simplify-code" "spike" "grounded-citations" "humanizer" "claude-code" "codex" "git-conventions"];
in {
  # Keep Hermes on a current uv2nix builder; flake.lock owns the exact revision.
  flake-file.inputs.uv2nix = {
    url = "github:pyproject-nix/uv2nix";
    inputs.nixpkgs.follows = "hermes-agent/nixpkgs";
    inputs.pyproject-nix.follows = "hermes-agent/pyproject-nix";
  };
  flake-file.inputs.hermes-agent = {
    url = "github:NousResearch/hermes-agent";
    inputs.uv2nix.follows = "uv2nix";
  };
  # Pinned to the sha in Hermes's plugin catalog (plugin-catalog/hwiki.yaml).
  flake-file.inputs.hermes-plugin-hwiki = {
    url = "github:ottosulin/hwiki/d1961956eaafbd64fef71cb7135d475efcc8f954";
    flake = false;
  };
  flake-file.inputs.hermes-official-plugins = {
    url = "github:NousResearch/hermes-official-plugins";
    flake = false;
  };
  flake-file.inputs.hermes-plugin-office-3d = {
    url = "github:oslook/hermes-desktop-plugin-office-3d";
    flake = false;
  };
  # Include from a user aspect: den hands the darwin daemon to that user's host.
  den.aspects.hermes = {
    homeManager = import ./_work.nix {inherit inputs models fallbacks disabledSkills;};
    darwin = import ./_darwin.nix;
  };
}

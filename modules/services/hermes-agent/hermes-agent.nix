{
  inputs,
  lib,
  ...
}: let
  models = import ./_models.nix;
  fallbacks = import ./_fallbacks.nix;
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
  den.aspects.hermes-agent.darwin = import ./_darwin.nix {inherit inputs lib models fallbacks;};
  den.aspects.hermes-work.homeManager = import ./_work.nix {inherit inputs models fallbacks;};
}

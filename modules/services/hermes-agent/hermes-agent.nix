{
  inputs,
  lib,
  ...
}: let
  models = import ./_models.nix;
  fallbacks = import ./_fallbacks.nix;
in {
  # Share a current builder with Honcho; flake.lock owns the exact revision.
  flake-file.inputs.uv2nix = {
    url = "github:pyproject-nix/uv2nix";
    inputs.nixpkgs.follows = "hermes-agent/nixpkgs";
    inputs.pyproject-nix.follows = "hermes-agent/pyproject-nix";
  };
  flake-file.inputs.hermes-agent = {
    url = "github:NousResearch/hermes-agent";
    inputs.uv2nix.follows = "uv2nix";
  };
  flake-file.inputs.hermes-plugin-honcho = {
    url = "github:plastic-labs/honcho";
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

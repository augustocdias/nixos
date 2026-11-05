{
  inputs,
  lib,
  ...
}: {
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
  den.aspects.hermes-agent = {
    darwin = import ./_darwin.nix {inherit inputs lib;};
    homeManager = import ./_linux.nix {inherit inputs lib;};
  };
}

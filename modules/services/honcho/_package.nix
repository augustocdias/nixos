{
  pkgs,
  lib,
  source,
  hermesInput,
}: let
  inherit (hermesInput.inputs) uv2nix pyproject-nix pyproject-build-systems;
  workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = source;};
  version = (builtins.fromTOML (builtins.readFile "${source}/pyproject.toml")).project.version;
  pythonSet =
    (pkgs.callPackage pyproject-nix.build.packages {
      python = pkgs.python313;
    }).overrideScope (lib.composeManyExtensions [
      pyproject-build-systems.overlays.default
      (workspace.mkPyprojectOverlay {sourcePreference = "wheel";})
    ]);
in {
  inherit source;
  # The root is a virtual uv project; PYTHONPATH supplies its source at runtime.
  python = pythonSet.mkVirtualEnv "honcho-${version}-env" {honcho = [];};
}

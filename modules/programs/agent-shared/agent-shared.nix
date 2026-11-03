{
  inputs,
  lib,
  ...
}: {
  flake-file.inputs.llm-agents.url = lib.mkDefault "github:numtide/llm-agents.nix";

  den.aspects.agent-shared.homeManager = {pkgs, ...}: {
    home.packages = [inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.terminal-browser];
  };
}

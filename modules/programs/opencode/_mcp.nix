{
  pkgs,
  lib,
}: let
  nvim-mcp-wrapper = pkgs.writeShellScriptBin "nvim-mcp" ''
    session="''${HERDR_WORKSPACE_ID:-dettached}"
    export NVIM_ADDRESS="$HOME/.cache/nvim/server-''${session}.pipe"
    exec ${lib.getExe' pkgs.nix "nix"} run github:paulburgess1357/nvim-mcp -- "$@"
  '';
in
  {
    context7 = {
      type = "local";
      command = ["npx" "-y" "@upstash/context7-mcp"];
      environment.DEFAULT_MINIMUM_TOKENS = "64000";
    };
    nvim = {
      type = "local";
      command = ["${nvim-mcp-wrapper}/bin/nvim-mcp"];
    };
    nixos = {
      type = "local";
      command = ["nix" "run" "github:utensils/mcp-nixos" "--"];
    };
  }
  // lib.optionalAttrs (!pkgs.stdenv.hostPlatform.isDarwin) {
    Notion = {
      type = "remote";
      url = "https://mcp.notion.com/mcp";
    };
    linear = {
      type = "remote";
      url = "https://mcp.linear.app/mcp";
    };
    datadog = {
      type = "remote";
      url = "https://mcp.datadoghq.eu/api/unstable/mcp-server/mcp";
    };
  }

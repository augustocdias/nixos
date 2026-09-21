{
  pkgs,
  lib,
}:
{
  context7 = {
    type = "local";
    command = ["npx" "-y" "@upstash/context7-mcp"];
    environment.DEFAULT_MINIMUM_TOKENS = "64000";
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

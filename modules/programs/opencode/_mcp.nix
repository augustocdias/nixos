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

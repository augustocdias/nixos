{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  async-timeout,
}:
buildHomeAssistantComponent (finalAttrs: {
  owner = "vas3k";
  domain = "berlin_transport";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "vas3k";
    repo = "home-assistant-berlin-transport";
    tag = "v${finalAttrs.version}";
    hash = "sha256-R+Tk2O20agogaK4z833p30RLQ/EFpb3QysCGCv86ShM=";
  };

  dependencies = [async-timeout];

  passthru = {
    # See the same note in _ha-mcp.nix: buildHomeAssistantComponent's
    # extendMkDerivation moves the position info into nixpkgs, so nix-update
    # needs --override-filename. Relative to the repo root.
    updateFile = "modules/services/home-assistant/_berlin-transport.nix";
  };

  meta = {
    description = "Berlin (BVG/VBB) public transport departure times for Home Assistant";
    homepage = "https://github.com/vas3k/home-assistant-berlin-transport";
    changelog = "https://github.com/vas3k/home-assistant-berlin-transport/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
  };
})

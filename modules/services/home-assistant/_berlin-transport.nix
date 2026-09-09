{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  async-timeout,
}:
buildHomeAssistantComponent (finalAttrs: {
  owner = "vas3k";
  domain = "berlin_transport";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "vas3k";
    repo = "home-assistant-berlin-transport";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ygXz5BjKe45KAdeemwepBgWgLPL07iWZxH/ZObiQc+o=";
  };

  dependencies = [async-timeout];

  meta = {
    description = "Berlin (BVG/VBB) public transport departure times for Home Assistant";
    homepage = "https://github.com/vas3k/home-assistant-berlin-transport";
    changelog = "https://github.com/vas3k/home-assistant-berlin-transport/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
  };
})

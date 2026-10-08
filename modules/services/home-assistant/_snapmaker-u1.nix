{
  buildHomeAssistantComponent,
  fetchFromGitHub,
  home-assistant,
}:
buildHomeAssistantComponent {
  owner = "kbaker827";
  domain = "snapmaker_u1";
  # Upstream never tags; the prefix is manifest.json's version.
  version = "0-unstable-2026-09-28";

  src = fetchFromGitHub {
    owner = "kbaker827";
    repo = "ha-snapmaker-u1";
    rev = "e462267b856a33f7881c95410653838ba248e1db";
    hash = "sha256-PPwAOwLppDA4vkNIr6xDpE0fwXw8th3ZXrb89a8VaeI=";
  };

  dependencies = [
    home-assistant.python3Packages.aiohttp
  ];

  passthru = {
    updatePolicy = "branch";
    # buildHomeAssistantComponent's extendMkDerivation moves the position info
    # into nixpkgs, so nix-update needs --override-filename.
    updateFile = "modules/services/home-assistant/_snapmaker-u1.nix";
  };

  # No meta.license: upstream ships no LICENSE file.
  meta = {
    description = "Snapmaker U1 3D printer (Moonraker) integration for Home Assistant";
    homepage = "https://github.com/kbaker827/ha-snapmaker-u1";
  };
}

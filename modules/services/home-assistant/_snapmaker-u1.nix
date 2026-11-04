{
  buildHomeAssistantComponent,
  fetchFromGitHub,
  home-assistant,
}:
buildHomeAssistantComponent {
  owner = "kbaker827";
  domain = "snapmaker_u1";
  # Upstream never tags; the prefix is manifest.json's version.
  version = "0-unstable-2026-11-02";

  src = fetchFromGitHub {
    owner = "kbaker827";
    repo = "ha-snapmaker-u1";
    rev = "f5a50ef8746f76da5402cd178a43a4feee523463";
    hash = "sha256-l3jmhmJYkDFIcZFd4dJV3OJrxnAr7zu6AhgKvM6+4eI=";
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

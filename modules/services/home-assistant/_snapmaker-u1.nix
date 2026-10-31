{
  buildHomeAssistantComponent,
  fetchFromGitHub,
  home-assistant,
}:
buildHomeAssistantComponent {
  owner = "kbaker827";
  domain = "snapmaker_u1";
  # Upstream never tags; the prefix is manifest.json's version.
  version = "0-unstable-2026-10-30";

  src = fetchFromGitHub {
    owner = "kbaker827";
    repo = "ha-snapmaker-u1";
    rev = "df0bc02767b542b5ce8d8a13b2acb0fc99ea2065";
    hash = "sha256-KwPmh9/es7GCqPcAtRfavgh6MvsY/d9bUx9ebubl2w8=";
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

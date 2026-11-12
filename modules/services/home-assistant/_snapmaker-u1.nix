{
  buildHomeAssistantComponent,
  fetchFromGitHub,
  home-assistant,
}:
buildHomeAssistantComponent {
  owner = "kbaker827";
  domain = "snapmaker_u1";
  # Upstream never tags; the prefix is manifest.json's version.
  version = "0-unstable-2026-11-10";

  src = fetchFromGitHub {
    owner = "kbaker827";
    repo = "ha-snapmaker-u1";
    rev = "a876f85db09bf67462dba63628710b3399444767";
    hash = "sha256-wKyVekux5elstAEbZUMxs5rJuCqgzPKSh30yIs4B0Ww=";
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

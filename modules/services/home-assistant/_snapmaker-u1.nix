{
  buildHomeAssistantComponent,
  fetchFromGitHub,
  home-assistant,
}:
buildHomeAssistantComponent {
  owner = "kbaker827";
  domain = "snapmaker_u1";
  # Upstream never tags; the prefix is manifest.json's version.
  version = "0-unstable-2026-10-14";

  src = fetchFromGitHub {
    owner = "kbaker827";
    repo = "ha-snapmaker-u1";
    rev = "1e1cd97c9f980c94da07a4602489635bb2cb1e19";
    hash = "sha256-e020/dxx+8S5vho+YVv+C9zerr0iLuNsoGw6m6a17Kg=";
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

{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
}:
buildHomeAssistantComponent (finalAttrs: {
  owner = "ironbiff";
  domain = "gruenbeck_softliq";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "ironbiff";
    repo = "ha-gruenbeck-softliq";
    tag = "v${finalAttrs.version}";
    hash = "sha256-G1qytX36j6hsWBZNrLoXd00TSpx5m0TElkQ47WlSh/8=";
  };

  passthru = {
    # buildHomeAssistantComponent's extendMkDerivation moves the position info
    # into nixpkgs, so nix-update needs --override-filename.
    updateFile = "modules/services/home-assistant/_gruenbeck-softliq.nix";
  };

  meta = {
    description = "Grünbeck softliQ water softener integration for Home Assistant";
    homepage = "https://github.com/ironbiff/ha-gruenbeck-softliq";
    changelog = "https://github.com/ironbiff/ha-gruenbeck-softliq/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
  };
})

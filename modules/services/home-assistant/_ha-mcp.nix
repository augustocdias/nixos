{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  python3Packages,
}:
# Only the component half lives here. The server it runs in process — the
# `ha-mcp` PyPI dist — is nixpkgs' `python3Packages.ha-mcp`; it reaches HA's
# interpreter via `dependencies` -> `propagatedBuildInputs` -> the module's
# `extraPackages`.
buildHomeAssistantComponent (finalAttrs: {
  owner = "homeassistant-ai";
  domain = "ha_mcp_tools";
  version = "2.2.0";

  src = fetchFromGitHub {
    owner = "homeassistant-ai";
    repo = "ha-mcp-integration";
    tag = "v${finalAttrs.version}";
    hash = "sha256-U8rW/743M//IO4lR+pH2GV5iLkrocsovoUb/uVTYPbE=";
  };

  # Every name here is a manifest.json requirement, enforced at build time by
  # manifestRequirementsCheckHook. `mcp` is the *shared* copy, new in 2.2.0 —
  # the server vendors its own under ha_mcp/_vendor/mcp, so it is not that one.
  dependencies = with python3Packages; [
    ha-mcp
    mcp
    ruamel-yaml
    voluptuous-openapi
  ];

  passthru = {
    updateFile = "modules/services/home-assistant/_ha-mcp.nix";
    updateVersionRegex = "^v?([0-9]+\\.[0-9]+\\.[0-9]+)$";
  };

  meta = {
    description = "Home Assistant integration hosting the ha-mcp server in process";
    homepage = "https://github.com/homeassistant-ai/ha-mcp-integration";
    changelog = "https://github.com/homeassistant-ai/ha-mcp-integration/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
  };
})

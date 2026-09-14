{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  python3Packages,
}: let
  ha-mcp = python3Packages.buildPythonPackage (finalAttrs: {
    pname = "ha-mcp";
    version = "8.4.3";
    pyproject = true;

    src = python3Packages.fetchPypi {
      pname = "ha_mcp";
      inherit (finalAttrs) version;
      hash = "sha256-qhP+xu7ZJSHAOmnToO636jqaIANpIfF3KnJaUIiYRBA=";
    };

    build-system = [python3Packages.setuptools];

    pythonRelaxDeps = [
      "pydantic-monty"
      "python-dotenv"
    ];

    dependencies = with python3Packages; [
      cryptography
      fastmcp
      httpx
      packaging
      pydantic
      pydantic-monty
      python-dotenv
      socksio
      truststore
      tzdata
    ];

    pythonImportsCheck = ["ha_mcp"];

    # The sdist ships no test suite.
    doCheck = false;

    meta = {
      description = "Model Context Protocol server for administering Home Assistant";
      homepage = "https://github.com/homeassistant-ai/ha-mcp";
      changelog = "https://github.com/homeassistant-ai/ha-mcp/releases";
      license = lib.licenses.mit;
    };
  });
in {
  inherit ha-mcp;

  ha-mcp-tools = buildHomeAssistantComponent (finalAttrs: {
    owner = "homeassistant-ai";
    domain = "ha_mcp_tools";
    version = "2.1.3";

    src = fetchFromGitHub {
      owner = "homeassistant-ai";
      repo = "ha-mcp-integration";
      tag = "v${finalAttrs.version}";
      hash = "sha256-RMKMW8OyfajHwlKEDgz2l0kEBX3TsnZQeIv7zRvjv/M=";
    };

    dependencies =
      (with python3Packages; [
        ruamel-yaml
        voluptuous-openapi
      ])
      ++ [ha-mcp];

    meta = {
      description = "Home Assistant integration hosting the ha-mcp server in process";
      homepage = "https://github.com/homeassistant-ai/ha-mcp-integration";
      changelog = "https://github.com/homeassistant-ai/ha-mcp-integration/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.mit;
    };
  });
}

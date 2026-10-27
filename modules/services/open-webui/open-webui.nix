{
  den,
  inputs,
  lib,
  ...
}: {
  den.aspects.open-webui = {
    darwin = {
      config,
      pkgs,
      ...
    }: let
      port = 8080;
      stateDir = "/var/lib/open-webui";

      secretPath = config.sops.secrets.open_webui_secret.path;

      python = pkgs.python3.override {
        packageOverrides = _: previous: {
          # WebUI 0.12.3 requires MCP 1; MCP 2 also breaks PostHog's tests.
          mcp = previous.mcp_1;
        };
      };
      package = (pkgs.open-webui.override {python3Packages = python.pkgs;}).overridePythonAttrs (old: {
        dependencies =
          (old.dependencies or [])
          ++ [
            # osm deps
            python.pkgs.openrouteservice
            python.pkgs.pygments
          ];
      });
      bootstrapPython = python.withPackages (ps: [(ps.toPythonModule package)]);
      credentialPaths = [
        secretPath
        config.sops.secrets.open_webui_augusto_password.path
        config.sops.secrets.open_webui_livia_password.path
        config.sops.secrets.hermes_augusto_api_key.path
        config.sops.secrets.hermes_livia_api_key.path
      ];

      tools = import ./_tools.nix {inherit (pkgs) fetchurl;};

      toolManifest = pkgs.writeText "open-webui-tools.json" (
        builtins.toJSON (
          lib.mapAttrs (_: tool: {
            inherit (tool) name;
            path = toString tool.src;
          })
          tools
        )
      );

      start = pkgs.writeShellScript "open-webui-start" ''
        set -eu
        umask 077
        for path in ${lib.escapeShellArgs credentialPaths}; do
          for _ in $(seq 1 60); do
            [ -s "$path" ] && break
            sleep 2
          done
          [ -s "$path" ] || { echo "Missing WebUI credential: $path" >&2; exit 1; }
        done
        export WEBUI_SECRET_KEY="$(cat ${secretPath})"
        export OPENAI_API_KEYS="$(cat ${config.sops.secrets.hermes_augusto_api_key.path});$(cat ${config.sops.secrets.hermes_livia_api_key.path})"
        export OWUI_AUGUSTO_PASSWORD_FILE=${config.sops.secrets.open_webui_augusto_password.path}
        export OWUI_LIVIA_PASSWORD_FILE=${config.sops.secrets.open_webui_livia_password.path}
        ${bootstrapPython}/bin/python ${./_bootstrap.py}
        exec ${lib.getExe package} serve \
          --host 0.0.0.0 \
          --port ${toString port}
      '';
    in {
      imports = lib.optionals (inputs ? sops-nix) [
        inputs.sops-nix.darwinModules.sops
      ];

      sops = {
        defaultSopsFile = ../../security/secrets/env.yaml;
        defaultSopsFormat = "yaml";
        age.keyFile = "/Users/augusto/.config/sops/age/keys.txt";
        secrets.open_webui_secret = {};
        secrets.open_webui_augusto_password = {};
        secrets.open_webui_livia_password = {};
      };

      launchd.daemons.open-webui = {
        command = "${start}";

        environment = {
          HOME = stateDir;
          DATA_DIR = "${stateDir}/data";
          HF_HOME = "${stateDir}/hf_home";
          SENTENCE_TRANSFORMERS_HOME = "${stateDir}/transformers_home";

          STATIC_DIR = "${stateDir}/static";
          FRONTEND_BUILD_DIR = "${package.frontend}/share/open-webui";

          WEBUI_URL = "http://127.0.0.1:${toString port}";

          ENABLE_OLLAMA_API = "False";
          ENABLE_OPENAI_API = "True";
          OPENAI_API_BASE_URLS = "http://127.0.0.1:8650/p/augusto/v1;http://127.0.0.1:8650/p/livia/v1";
          OPENAI_API_CONFIGS = builtins.toJSON {
            "0" = {
              enable = true;
              model_ids = ["hermes-agent"];
              prefix_id = "augusto";
            };
            "1" = {
              enable = true;
              model_ids = ["hermes-agent"];
              prefix_id = "livia";
            };
          };

          WEBUI_AUTH = "True";
          ENABLE_SIGNUP = "False";
          BYPASS_ADMIN_ACCESS_CONTROL = "False";
          BYPASS_MODEL_ACCESS_CONTROL = "False";
          ENABLE_ADMIN_CHAT_ACCESS = "False";

          ENABLE_WEB_SEARCH = "True";
          WEB_SEARCH_ENGINE = "duckduckgo";

          ENABLE_PERSISTENT_CONFIG = "False";

          # Frontmatter requirements would be pip-installed into the store.
          ENABLE_PIP_INSTALL_FRONTMATTER_REQUIREMENTS = "False";

          ENABLE_VERSION_UPDATE_CHECK = "False";
          ANONYMIZED_TELEMETRY = "False";
          DO_NOT_TRACK = "1";
          SCARF_NO_ANALYTICS = "True";
        };

        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
          WorkingDirectory = stateDir;
          StandardOutPath = "/var/log/open-webui.log";
          StandardErrorPath = "/var/log/open-webui.log";
        };
      };

      launchd.daemons.open-webui-tools = {
        command = "${pkgs.python3}/bin/python3 ${./import-tools.py}";

        environment = {
          OWUI_BASE_URL = "http://127.0.0.1:${toString port}";
          OWUI_DB = "${stateDir}/data/webui.db";
          OWUI_SECRET_FILE = secretPath;
          OWUI_TOOL_MANIFEST = "${toolManifest}";
        };

        serviceConfig = {
          KeepAlive = {SuccessfulExit = false;};
          RunAtLoad = true;
          WorkingDirectory = stateDir;
          StandardOutPath = "/var/log/open-webui-tools.log";
          StandardErrorPath = "/var/log/open-webui-tools.log";
        };
      };

      system.activationScripts.postActivation.text = ''
        mkdir -p ${stateDir}/{data,hf_home,transformers_home,static}
      '';
    };
  };
}

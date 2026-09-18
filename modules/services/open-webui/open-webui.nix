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

      start = pkgs.writeShellScript "open-webui-start" ''
        set -eu
        for _ in $(seq 1 60); do
          [ -r ${secretPath} ] && break
          echo "waiting for ${secretPath}..."
          sleep 2
        done
        export WEBUI_SECRET_KEY="$(cat ${secretPath})"
        exec ${lib.getExe pkgs.open-webui} serve \
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
      };

      launchd.daemons.open-webui = {
        command = "${start}";

        environment = {
          HOME = stateDir;
          DATA_DIR = "${stateDir}/data";
          HF_HOME = "${stateDir}/hf_home";
          SENTENCE_TRANSFORMERS_HOME = "${stateDir}/transformers_home";

          STATIC_DIR = "${stateDir}/static";

          WEBUI_URL = "http://127.0.0.1:${toString port}";

          OLLAMA_BASE_URL = "http://127.0.0.1:11434";
          ENABLE_OLLAMA_API = "True";
          ENABLE_OPENAI_API = "False";

          WEBUI_AUTH = "False";
          ENABLE_SIGNUP = "False";

          ENABLE_WEB_SEARCH = "True";
          WEB_SEARCH_ENGINE = "duckduckgo";

          ENABLE_PERSISTENT_CONFIG = "False";

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

      system.activationScripts.postActivation.text = ''
        mkdir -p ${stateDir}/{data,hf_home,transformers_home,static}
      '';
    };
  };
}

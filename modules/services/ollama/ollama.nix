{lib, ...}: {
  perSystem = {pkgs, ...}: let
    release = pkgs.callPackage ./_package.nix {};
  in {
    packages =
      {ollama-darwin-source = release.source;}
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
        ollama-bin = release.package;
      };
  };
  den.aspects.ollama.darwin = {pkgs, ...}: let
    ollama = (pkgs.callPackage ./_package.nix {}).package;
    ollamaHome = "/var/lib/ollama";
    ollamaPort = 11434;
    ollamaModels = ["gemma4:12b-mlx" "qwen3-embedding:0.6b"];
    # launchd has no ordering, so poll the server instead of racing it.
    ollamaModelLoader = pkgs.writeShellScript "ollama-model-loader" ''
      set -u
      until ${lib.getExe pkgs.curl} -fsS --max-time 5 \
        "http://127.0.0.1:${toString ollamaPort}/api/version" >/dev/null; do
        echo "waiting for ollama on port ${toString ollamaPort}..."
        sleep 2
      done

      status=0
      ${lib.concatMapStringsSep "\n" (model: ''
          echo "pulling ${model}"
          ${lib.getExe ollama} pull ${lib.escapeShellArg model} || status=1
        '')
        ollamaModels}
      exit "$status"
    '';
  in {
    launchd.daemons.ollama = {
      command = "${lib.getExe ollama} serve";
      environment = {
        HOME = ollamaHome;
        OLLAMA_HOST = "[::]:${toString ollamaPort}";
        OLLAMA_MODELS = "${ollamaHome}/models";
        OLLAMA_CONTEXT_LENGTH = "65536";
        OLLAMA_KEEP_ALIVE = "-1";
        OLLAMA_NUM_PARALLEL = "3";
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_NO_CLOUD = "1";
      };
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/ollama.log";
        StandardErrorPath = "/var/log/ollama.log";
      };
    };
    launchd.daemons.ollama-model-loader = {
      command = "${ollamaModelLoader}";
      environment = {
        HOME = ollamaHome;
        OLLAMA_HOST = "127.0.0.1:${toString ollamaPort}";
        OLLAMA_MODELS = "${ollamaHome}/models";
      };
      serviceConfig = {
        # One-shot: retry on failure, don't respawn after a clean pull.
        KeepAlive = {SuccessfulExit = false;};
        RunAtLoad = true;
        StandardOutPath = "/var/log/ollama-model-loader.log";
        StandardErrorPath = "/var/log/ollama-model-loader.log";
      };
    };
    system.activationScripts.postActivation.text = ''
      mkdir -p ${ollamaHome}/models
    '';
  };
}

{
  den,
  lib,
  ...
}: {
  # Laya (local System One decision model) served over TypeSafe's
  # /v1/systemone wire protocol, for the Home Assistant `laya` conversation
  # agent on the Pi. LAN-reachable and unauthenticated on purpose: it can only
  # score questions, never act.
  den.aspects.laya = {
    darwin = {pkgs, ...}: let
      port = 8000;
      stateDir = "/var/lib/laya";

      laya = pkgs.python3Packages.buildPythonPackage rec {
        pname = "laya";
        version = "0.3.28";
        format = "wheel";

        src = pkgs.fetchPypi {
          inherit pname version format;
          dist = "py3";
          python = "py3";
          hash = "sha256-oUk8/0dMCl2Ehh21XAxcmxfx24Vh5Fh2TamjItxUKog=";
        };

        # Core deps plus the `serve` extra.
        dependencies = with pkgs.python3Packages; [
          torch
          transformers
          safetensors
          huggingface-hub
          numpy
          fastapi
          uvicorn
          python-multipart
        ];

        # laya.serve defers its heavy imports, so this stays cheap.
        pythonImportsCheck = ["laya" "laya.serve"];

        meta = {
          description = "Calibrated decision model with a /v1/systemone server";
          homepage = "https://huggingface.co/convaiinnovations/laya";
          license = lib.licenses.asl20;
          mainProgram = "laya-serve";
        };
      };
    in {
      launchd.daemons.laya = {
        command = lib.getExe laya;

        environment = {
          # launchd daemons inherit no HOME; HF caches under it otherwise.
          HOME = stateDir;
          HF_HOME = "${stateDir}/hf";

          LAYA_HOST = "0.0.0.0";
          LAYA_PORT = toString port;
          LAYA_DEVICE = "mps";

          # The HA agent pins `model` per request; only this one is needed.
          LAYA_MODELS = "multilingual";
          LAYA_DEFAULT_MODEL = "multilingual";
          LAYA_MAX_LOADED = "1";

          # The checkpoint SHA this laya release reviewed: weights change only
          # when the package is bumped. Downloaded on first start (~1 GB).
          LAYA_REVISION = "reviewed";
        };

        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
          WorkingDirectory = stateDir;
          StandardOutPath = "/var/log/laya.log";
          StandardErrorPath = "/var/log/laya.log";
        };
      };

      system.activationScripts.postActivation.text = ''
        mkdir -p ${stateDir}/hf
      '';
    };
  };
}

{lib, ...}: {
  den.aspects.wyoming.darwin = {pkgs, ...}: let
    # Custom piper voices from OpenVoiceOS, deployed into --data-dir on
    # activation so wyoming-piper auto-discovers them alongside the catalog.
    # Each entry is { name, onnx, config } — name must match the .onnx stem
    # that find_voice() looks up.  The config is patched to set dataset and
    # audio.quality so HA shows a readable name instead of "working (training)".
    piperVoices = let
      patchConfig = {
        src,
        dataset,
        quality,
      }:
        pkgs.runCommand "piper-config-patched.json" {
          nativeBuildInputs = [pkgs.jq];
        } ''
          jq '.dataset = $d | .audio.quality = $q' \
            --arg d "${dataset}" --arg q "${quality}" \
            < ${src} > $out
        '';
    in [
      {
        name = "dii_pt-BR";
        onnx = pkgs.fetchurl {
          url = "https://huggingface.co/OpenVoiceOS/pipertts_pt-BR_dii/resolve/main/dii_pt-BR.onnx";
          hash = "sha256-+xWkR7p0grki4dL+/qccEDH3YOcr4kzOd5Tib+EdCGs=";
        };
        config = patchConfig {
          src = pkgs.fetchurl {
            url = "https://huggingface.co/OpenVoiceOS/pipertts_pt-BR_dii/resolve/main/dii_pt-BR.onnx.json";
            hash = "sha256-MGmYKVrJakSdQ6Gciq1lsx4EA0HhXey99Kpo2IZw7IQ=";
          };
          dataset = "Dii pt-BR";
          quality = "medium";
        };
      }
    ];
  in {
    launchd.daemons.wyoming-faster-whisper = {
      command = lib.concatStringsSep " " [
        (lib.getExe pkgs.wyoming-faster-whisper)
        "--data-dir /var/lib/wyoming/faster-whisper"
        "--uri tcp://0.0.0.0:10300"
        "--model small-int8"
        "--language auto"
      ];
      # https://github.com/rhasspy/wyoming-faster-whisper/issues/27
      environment.HF_HOME = "/tmp";
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/wyoming-faster-whisper.log";
        StandardErrorPath = "/var/log/wyoming-faster-whisper.log";
      };
    };
    launchd.daemons.wyoming-piper = {
      command = lib.concatStringsSep " " [
        (lib.getExe pkgs.wyoming-piper)
        "--data-dir /var/lib/wyoming/piper"
        "--uri tcp://0.0.0.0:10200"
        "--voice en_US-libritts-high"
        "--speaker 0"
      ];
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/wyoming-piper.log";
        StandardErrorPath = "/var/log/wyoming-piper.log";
      };
    };
    system.activationScripts.postActivation.text = ''
      mkdir -p /var/lib/wyoming/faster-whisper
      mkdir -p /var/lib/wyoming/piper

      ${lib.concatMapStringsSep "\n" (voice: ''
          cmp -s "${voice.onnx}" "/var/lib/wyoming/piper/${voice.name}.onnx" \
            || cp --no-preserve=mode "${voice.onnx}" "/var/lib/wyoming/piper/${voice.name}.onnx"
          cmp -s "${voice.config}" "/var/lib/wyoming/piper/${voice.name}.onnx.json" \
            || cp --no-preserve=mode "${voice.config}" "/var/lib/wyoming/piper/${voice.name}.onnx.json"
        '')
        piperVoices}
    '';
  };
}

{
  den,
  lib,
  ...
}: {
  # LibreTranslate (offline, Argos models) for the HA `laya` agent: non-English
  # voice commands are translated to English before Laya reads them. Only
  # en<->pt is installed. LAN-reachable and unauthenticated, like laya.
  # nixpkgs' services.libretranslate is NixOS-only, hence a launchd daemon.
  den.aspects.libretranslate = {
    darwin = {pkgs, ...}: let
      port = 5000;
      stateDir = "/var/lib/libretranslate";
    in {
      launchd.daemons.libretranslate = {
        command = lib.concatStringsSep " " [
          (lib.getExe pkgs.libretranslate)
          "--host 0.0.0.0"
          "--port ${toString port}"
          "--load-only en,pt"
          "--disable-web-ui"
          "--disable-files-translation"
          "--threads 2"
        ];

        environment = {
          # launchd daemons inherit no HOME; argos derives every path from it
          # and the XDG vars, so all of them point into the state dir.
          HOME = stateDir;
          XDG_DATA_HOME = "${stateDir}/data";
          XDG_CACHE_HOME = "${stateDir}/cache";
          XDG_CONFIG_HOME = "${stateDir}/config";
        };

        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
          WorkingDirectory = stateDir;
          StandardOutPath = "/var/log/libretranslate.log";
          StandardErrorPath = "/var/log/libretranslate.log";
        };
      };

      # The en<->pt models (~160 MB) are fetched on first start.
      system.activationScripts.postActivation.text = ''
        mkdir -p ${stateDir}/{data,cache,config}
      '';
    };
  };
}

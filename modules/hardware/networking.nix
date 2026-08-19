{den, ...}: {
  den.aspects.networking = {
    nixos = {
      networking.networkmanager = {
        enable = true;
      };
      services.resolved.enable = true;

      # Avoid blocking boot waiting for network
      systemd.services.NetworkManager-wait-online.enable = false;
      networking.extraHosts = ''
        0.0.0.0 sfrclak.com
      '';

      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
        settings = {
          General = {
            Enable = "Source,Sink,Media,Socket";
            Experimental = true;
            ClassicBondedOnly = false;
          };
        };
      };
    };
  };
}

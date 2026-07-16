{den, ...}: {
  den.aspects.networking = {
    nixos = {
      networking.networkmanager = {
        enable = true;
        settings = {
          "connection-ethernet" = {
            match-device = "type:ethernet";
            "ipv4.route-metric" = 50;
            "ipv6.route-metric" = 50;
          };
          "connection-wifi" = {
            match-device = "type:wifi";
            "ipv4.route-metric" = 100;
            "ipv6.route-metric" = 100;
          };
        };
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

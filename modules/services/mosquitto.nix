{den, ...}: {
  den.aspects.mosquitto = {
    nixos = {
      config,
      lib,
      ...
    }: let
      consumers = {
        # Add users here. It must match the middle portion of sops secret name: mqtt_USER_password
        ha = ["readwrite #"]; # this is for home-assistant's integration
      };
    in {
      sops.secrets =
        lib.mapAttrs'
        (name: _: lib.nameValuePair "mqtt_${name}_password" {})
        consumers;

      services.mosquitto = {
        enable = true;
        persistence = true;

        listeners = [
          {
            port = 1883;

            users =
              lib.mapAttrs
              (name: acl: {
                passwordFile = config.sops.secrets."mqtt_${name}_password".path;
                inherit acl;
              })
              consumers;
          }
        ];
      };

      networking.firewall.allowedTCPPorts = [1883];
    };
  };
}

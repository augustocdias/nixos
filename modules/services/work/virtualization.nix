{den, ...}: {
  den.aspects.virtualization = {
    nixos = {pkgs, ...}: {
      users.users.augusto.extraGroups = ["libvirtd"];

      virtualisation.libvirtd = {
        enable = true;
        qemu = {
          swtpm.enable = true;
          vhostUserPackages = [pkgs.virtiofsd];
        };
      };

      virtualisation.containers.registries.settings = {
        unqualified-search-registries = ["docker.io"];
        registry = [
          {location = "docker.io";}
          {location = "quay.io";}
        ];
      };

      environment.systemPackages = [
        pkgs.quickemu
      ];

      programs.virt-manager.enable = true;
      virtualisation.spiceUSBRedirection.enable = true;

      # Allow VM traffic to reach host services through the libvirt bridge
      networking.firewall.interfaces."virbr0".allowedTCPPortRanges = [
        {
          from = 1;
          to = 65535;
        }
      ];

      # Fix upstream libvirt service that hardcodes /usr/bin/sh
      systemd.services.virt-secret-init-encryption.serviceConfig.ExecStart = let
        sh = "${pkgs.bash}/bin/sh";
        dd = "${pkgs.coreutils}/bin/dd";
        systemd-creds = "${pkgs.systemd}/bin/systemd-creds";
      in [
        ""
        "${sh} -c 'umask 0077 && (${dd} if=/dev/random status=none bs=32 count=1 | ${systemd-creds} encrypt --name=secrets-encryption-key - /var/lib/libvirt/secrets/secrets-encryption-key)'"
      ];

      systemd.tmpfiles.rules = [
        "d /var/lib/swtpm-localca 0750 tss tss -"
      ];
    };
  };
}

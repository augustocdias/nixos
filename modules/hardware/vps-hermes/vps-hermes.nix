{den, ...}: {
  den.aspects.vps-hermes = {
    includes = with den.aspects; [
      disko
      server-base
      podman
    ];

    nixos = {
      config,
      lib,
      modulesPath,
      ...
    }: {
      imports = [(modulesPath + "/profiles/qemu-guest.nix")];

      # Hermes runs unsandboxed, so its user gets no sudo, no Nix trust and no login password.
      users.users.hermes = {
        uid = 1001;
        # den's primary-user battery adds wheel to every user.
        extraGroups = lib.mkForce [];
        linger = true;
        openssh.authorizedKeys.keys = config.users.users.augusto.openssh.authorizedKeys.keys;
      };

      boot.loader.grub = {
        enable = true;
        # Hybrid boot: the EF02 partition serves BIOS firmware, the ESP serves UEFI.
        efiSupport = true;
        efiInstallAsRemovable = true;
      };

      disko.devices.disk.main = {
        # limit: Hetzner's default; confirm with lsblk in the rescue system before installing.
        device = "/dev/sda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02";
              priority = 1;
            };
            ESP = {
              size = "512M";
              type = "EF00";
              priority = 2;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };

      networking = {
        useDHCP = false;
        useNetworkd = true;
      };
      systemd.network.networks."10-wan" = {
        matchConfig.Name = "en* eth*";
        networkConfig.DHCP = "ipv4";
        # limit: Hetzner gives IPv6 by static assignment only; add the server's /64 here after provisioning:
        #   address = ["<prefix>::1/64"];
        #   routes = [{Gateway = "fe80::1";}];
      };
    };
  };
}

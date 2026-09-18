{
  den,
  inputs,
  lib,
  ...
}: {
  flake-file.inputs.nixos-raspberrypi.url = lib.mkDefault "github:nvmd/nixos-raspberrypi/main";

  den.aspects.raspi = {
    includes = with den.aspects; [
      disko
      home-assistant
      mosquitto
    ];

    # To install this directly on a SD card run:
    # sudo nix run github:nix-community/disko -- --mode destroy,format,mount --flake .#raspi
    # sudo nixos-install --root /mnt --flake .#raspi --no-root-password
    # sudo umount -R /mnt
    # IMPORANT: Don't forget to first update the `installDisk` value bellow
    nixos = {pkgs, ...}: let
      # Re-confirm the target is the right device before running disko:
      #   lsblk -o NAME,SIZE,TRAN,FSTYPE /dev/sda
      installDisk = "/dev/disk/by-id/usb-Generic_MassStorageClass_000000002957-0:0";

      vendorLinuxPackages =
        inputs.nixos-raspberrypi.packages.${pkgs.stdenv.hostPlatform.system}.linuxPackages_rpi4.extend
        (_: super: {
          kernel = super.kernel.overrideAttrs (o: {
            passthru =
              (o.passthru or {})
              // {
                target = "Image";
                buildDTBs = true;
              };
          });
        });
    in {
      imports = [
        inputs.nixos-raspberrypi.lib.inject-overlays
        inputs.nixos-raspberrypi.nixosModules.trusted-nix-caches
        inputs.nixos-raspberrypi.nixosModules.raspberry-pi-4.base
        inputs.nixos-raspberrypi.nixosModules.raspberry-pi-4.bluetooth
        inputs.sops-nix.nixosModules.sops
      ];

      _module.args.nixos-raspberrypi = inputs.nixos-raspberrypi;

      boot.supportedFilesystems.zfs = lib.mkForce false;
      boot.loader.raspberry-pi.bootloader = "kernel";

      boot.kernelPackages = vendorLinuxPackages;
      hardware.deviceTree.enable = true;

      users.groups.gpio = {};
      boot.kernelParams = ["iomem=relaxed"];
      services.udev.extraRules = lib.mkBefore ''
        KERNEL=="gpiomem", GROUP="gpio", MODE="0660"
        SUBSYSTEM=="gpio", KERNEL=="gpiochip*", ACTION=="add", PROGRAM="${pkgs.bash}/bin/bash -c '${pkgs.coreutils}/bin/chgrp gpio /dev/%k && chmod 660 /dev/%k && ${pkgs.coreutils}/bin/chgrp -R gpio /sys/class/gpio && ${pkgs.coreutils}/bin/chmod -R g=u /sys/class/gpio'"
        SUBSYSTEM=="gpio", ACTION=="add", PROGRAM="${pkgs.bash}/bin/bash -c '${pkgs.coreutils}/bin/chgrp -R gpio /sys%p && ${pkgs.coreutils}/bin/chmod -R g=u /sys%p'"
      '';

      disko.devices.disk.main = {
        device = installDisk;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            FIRMWARE = {
              size = "512M";
              type = "0700";
              priority = 1;
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/firmware";
                mountOptions = ["fmask=0022" "dmask=0022"];
                extraArgs = ["-n" "FIRMWARE"];
              };
            };
            root = {
              size = "100%";
              priority = 2;
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                extraArgs = ["-L" "NIXOS"];
              };
            };
          };
        };
      };

      time.timeZone = "Europe/Berlin";
      i18n = {
        defaultLocale = "en_US.UTF-8";
        extraLocaleSettings = {
          LC_TIME = "de_DE.UTF-8";
          LC_MONETARY = "de_DE.UTF-8";
          LC_PAPER = "de_DE.UTF-8";
          LC_MEASUREMENT = "de_DE.UTF-8";
        };
      };
      console.keyMap = "us";

      networking = {
        useDHCP = false;
        useNetworkd = true;
        firewall = {
          enable = true;
          allowedTCPPorts = [8123 21064];
          allowedUDPPorts = [5353];
        };
      };

      systemd.network.networks."10-lan" = {
        matchConfig.Name = "en* eth*";
        networkConfig = {
          DHCP = "ipv4";
          IPv6AcceptRA = true;
        };
        linkConfig.RequiredForOnline = "routable";
      };

      services.resolved.enable = true;

      services.avahi = {
        enable = true;
        publish = {
          enable = true;
          addresses = true;
        };
        nssmdns4 = true;
        nssmdns6 = true;
      };

      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
      };

      nix.settings.trusted-users = ["root" "augusto"];
      users.mutableUsers = false;
      users.users.augusto = {
        isNormalUser = true;
        description = "Augusto";
        extraGroups = ["wheel"];
        shell = pkgs.fish;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE8G/L1OaaDxw1pFQ8vYKVBSMnPZbty8AiUECQaHwNmW"
        ];
      };

      programs.fish = {
        enable = true;
        interactiveShellInit = "fish_vi_key_bindings";
      };

      programs.starship = {
        enable = true;
        settings = {
          format = "$username$hostname$directory$nix_shell$cmd_duration$line_break$character";

          username = {
            show_always = true;
            style_user = "yellow";
            style_root = "red";
            format = "[$user]($style)";
          };

          hostname = {
            ssh_only = false;
            style = "green";
            format = "@[$hostname]($style) ";
          };

          directory = {
            style = "blue";
            truncation_length = 3;
            truncation_symbol = "…/";
            read_only = " 󰌾";
          };

          nix_shell = {
            symbol = " ";
            style = "cyan";
            format = "[$symbol$state]($style) ";
          };

          cmd_duration = {
            min_time = 2000;
            style = "yellow";
          };

          character = {
            success_symbol = "[❯](bold green)";
            error_symbol = "[❯](bold red)";
            vimcmd_symbol = "[❮](bold green)";
            vimcmd_replace_one_symbol = "[❮](bold purple)";
            vimcmd_replace_symbol = "[❮](bold purple)";
            vimcmd_visual_symbol = "[❮](bold yellow)";
          };
        };
      };

      security.sudo.wheelNeedsPassword = false;

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
        };
        extraConfig = "StreamLocalBindUnlink yes";
      };

      services.journald.settings.Journal.SystemMaxUse = "200M";

      sops = {
        defaultSopsFile = ../../security/secrets/env.yaml;
        defaultSopsFormat = "yaml";
        age.keyFile = "/var/lib/sops-nix/key.txt";
        secrets = {};
      };
    };
  };
}

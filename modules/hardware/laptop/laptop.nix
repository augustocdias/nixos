{den, ...}: {
  den.aspects.laptop = {
    includes = with den.aspects; [
      disko
      boot
      networking
      input-devices
      locale
    ];

    nixos = {pkgs, ...}: {
      imports = [./_hardware-configuration.nix];

      users.users.augusto.extraGroups = ["i2c"];

      disko.devices = {
        disk.main = {
          device = "/dev/nvme0n1";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                size = "512M";
                type = "EF00";
                priority = 1;
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = ["fmask=0022" "dmask=0022"];
                };
              };
              swap = {
                size = "29.8G";
                priority = 2;
                content = {
                  type = "swap";
                };
              };
              root = {
                size = "100%";
                priority = 3;
                content = {
                  type = "luks";
                  name = "cryptroot";
                  settings = {
                    crypttabExtraOpts = ["tpm2-device=auto"];
                  };
                  content = {
                    type = "filesystem";
                    format = "ext4";
                    mountpoint = "/";
                  };
                };
              };
            };
          };
        };
      };

      environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";

      hardware = {
        enableRedistributableFirmware = true;
        graphics = {
          enable = true;
          extraPackages = with pkgs; [
            intel-media-driver
            vpl-gpu-rt
            intel-compute-runtime
          ];
        };
        i2c.enable = true;
      };

      security.rtkit.enable = true;

      services = {
        pulseaudio.enable = false;

        pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          wireplumber = {
            enable = true;
            extraConfig = {
              # Bluetooth codec preferences
              "50-bluez-config"."monitor.bluez.properties" = {
                "bluez5.enable-sbc-xq" = true;
                "bluez5.enable-msbc" = true;
                "bluez5.enable-hw-volume" = false;
              };
              "99-disable-hdmi-audio"."monitor.alsa.rules" = [
                {
                  matches = [{"node.name" = "~alsa_output.*HDMI*";}];
                  actions.update-props = {"node.disabled" = true;};
                }
              ];
              # Default to Speaker profile on Arrow Lake audio.
              # Jack detection auto-switches to Headphones when plugged in.
              "98-default-speaker-profile"."monitor.alsa.rules" = [
                {
                  matches = [{"device.name" = "alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic";}];
                  actions.update-props = {
                    "device.profile" = "HiFi (HDMI1, HDMI2, HDMI3, Mic1, Mic2, Speaker)";
                  };
                }
              ];
            };
          };
        };

        printing = {
          enable = true;
          browsed.enable = false;
        };
        avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
        };

        upower.enable = true;
        power-profiles-daemon.enable = true;
        udisks2.enable = true;
      };
    };
  };
}

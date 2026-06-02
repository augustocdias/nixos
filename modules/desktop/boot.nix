{
  den,
  inputs,
  lib,
  ...
}: {
  flake-file.inputs.catppuccin-grub = {
    url = lib.mkDefault "github:catppuccin/grub/0a37ab19f654e77129b409fed371891c01ffd0b9";
    flake = false;
  };

  den.aspects.boot = {
    nixos = {pkgs, ...}: let
      catppuccin-grub-theme = pkgs.stdenv.mkDerivation {
        pname = "catppuccin-grub-theme";
        version = "1.0.0";
        src = inputs.catppuccin-grub;
        installPhase = ''
          mkdir -p $out
          cp -r src/catppuccin-mocha-grub-theme/* $out/
        '';
      };
    in {
      boot = {
        initrd = {
          systemd.enable = true;
          verbose = false;
          availableKernelModules = ["tpm_crb" "tpm_tis"];
        };

        plymouth = {
          enable = true;
          theme = "catppuccin-mocha";
          themePackages = [
            (pkgs.catppuccin-plymouth.override {variant = "mocha";})
          ];
        };

        # ACPI AC adapter module reports online=1 permanently on this laptop,
        # preventing UPower from detecting battery state.
        # Actual charging is handled by the UCSI subsystem.
        blacklistedKernelModules = ["ac"];

        consoleLogLevel = 0;
        kernelParams = [
          "quiet"
          "splash"
          "loglevel=3"
          "udev.log_level=3"
          "rd.systemd.show_status=auto"
          "i915.enable_guc=3"
        ];

        loader = {
          systemd-boot.enable = lib.mkForce false;
          grub = {
            enable = true;
            device = "nodev";
            efiSupport = true;
            useOSProber = true;
            theme = catppuccin-grub-theme;
          };
          efi.canTouchEfiVariables = true;
        };
      };

      services.logind.settings.Login = {
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "suspend";
        HandleLidSwitchDocked = "ignore";
        HandlePowerKey = "suspend";
        HandlePowerKeyLongPress = "poweroff";
      };
    };
  };
}

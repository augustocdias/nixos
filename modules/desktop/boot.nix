{
  den,
  inputs,
  lib,
  ...
}: {
  flake-file.inputs.grub2-themes = {
    url = lib.mkDefault "github:vinceliuice/grub2-themes";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  flake-file.inputs.win98se-plymouth = {
    url = lib.mkDefault "github:nilp0inter/plymouth-theme-win98se-inspired-nixos-theme";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.boot = {
    nixos = {
      imports =
        lib.optionals (inputs ? win98se-plymouth) [inputs.win98se-plymouth.nixosModules.default]
        ++ lib.optionals (inputs ? grub2-themes) [inputs.grub2-themes.nixosModules.default];

      boot = {
        initrd = {
          systemd.enable = true;
          verbose = false;
          availableKernelModules = ["tpm_crb" "tpm_tis"];
        };

        plymouth.enable = true;

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
          };
          efi.canTouchEfiVariables = true;

          grub2-theme = {
            enable = true;
            theme = "stylish";
            icon = "white";
            screen = "4k";
          };
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

{
  inputs,
  lib,
  ...
}: {
  flake.nixosConfigurations.installer = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      {nixpkgs.hostPlatform = "x86_64-linux";}
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
      {isoImage.squashfsCompression = "lz4";}
      ../installer/iso-config.nix
      {
        # Embed the entire repo into the ISO for offline installs
        environment.etc."nixos-installer/repo" = {
          source = lib.cleanSource ./..;
          mode = "0755";
        };
      }
    ];
  };

  perSystem = _: {
    packages.installer =
      inputs.self.nixosConfigurations.installer.config.system.build.isoImage;
  };
}

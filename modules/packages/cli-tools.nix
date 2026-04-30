{den, ...}: {
  den.aspects.cli-tools = {
    homeManager = {
      pkgs,
      lib,
      ...
    }: {
      home.packages = with pkgs;
        [
          eza
          fd
          lsof
          ripgrep
          starship
          bat
          delta
          moreutils
          htop
          btop
          tree
          p7zip
          zoxide
          age
          sops
          openssl
          yubikey-manager
          yubikey-personalization
          yubico-piv-tool
          ffmpeg
          imagemagick
          exiftool
          poppler-utils
          tesseract
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          dragon-drop
        ];
    };
  };
}

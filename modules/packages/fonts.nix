{den, ...}: {
  den.aspects.fonts = {
    homeManager = {
      pkgs,
      lib,
      ...
    }: {
      home.packages = with pkgs;
        [
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-color-emoji
          fira-code
          fira-code-symbols
          font-awesome
          comic-neue
        ]
        ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);

      fonts.fontconfig = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        enable = true;
        hinting = "full";
      };
    };
  };
}

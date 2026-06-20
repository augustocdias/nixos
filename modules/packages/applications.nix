{den, ...}: {
  den.aspects.applications = {
    homeManager = {
      pkgs,
      lib,
      ...
    }: {
      home.packages = with pkgs;
        [
          zed-editor
          zmk-studio
          drawio
        ]
        ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
          cider-2
          imv
          peazip
        ];
    };
  };
}

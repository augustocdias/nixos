{den, ...}: {
  den.aspects.applications = {
    homeManager = {
      pkgs,
      lib,
      ...
    }: {
      home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux (with pkgs; [
        cider-2
        zed-editor
        imv
        peazip
        drawio
      ]);
    };
  };
}

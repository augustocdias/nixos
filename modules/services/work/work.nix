{den, ...}: {
  den.aspects.work = {
    includes = with den.aspects; [
      podman
      virtualization
      teamviewer
      lotion
      datagrip
      slack
      wireguard
      sqlit
    ];

    homeManager = {pkgs, ...}: {
      home.packages = with pkgs; [
        just
        awscli2
      ];
    };
  };
}

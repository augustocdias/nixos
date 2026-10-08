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
      jgrep
      claude-code
      claude-code-jail
    ];

    homeManager = {pkgs, ...}: {
      home.packages = with pkgs; [
        just
        awscli2
      ];
    };
  };
}

{den, ...}: {
  den.aspects.user-linux = {
    includes = with den.aspects; [
      user-base

      users
      hyprland
      login-manager
      firefox
      thunderbird
      mpv
      xdg
      opencode-jail
      omp-jail
      work
    ];
  };
}

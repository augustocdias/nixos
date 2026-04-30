{den, ...}: {
  den.aspects.user-macos = {
    includes = with den.aspects; [
      user-base
    ];

    homeManager = {pkgs, ...}: {
      home.packages = with pkgs; [
        _1password-gui
        _1password-cli
        godot_4
        raycast
      ];
    };
  };
}

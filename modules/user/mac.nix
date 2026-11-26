{den, ...}: {
  den.aspects.user-macos = {
    includes = with den.aspects; [
      user-base
      omniwm
      hermes
    ];

    homeManager = {pkgs, ...}: {
      home.packages = with pkgs; [
        _1password-cli
        godot_4
        raycast
      ];
    };
  };
}

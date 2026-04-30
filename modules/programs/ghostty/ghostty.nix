{den, ...}: {
  den.aspects.ghostty = {
    homeManager = {
      config,
      pkgs,
      ...
    }: let
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

      commonSettings = {
        # Theme
        theme = "Catppuccin Mocha";

        # Font configuration
        font-family = "MonaspiceNe Nerd Font";
        font-family-italic = "MonaspiceRn Nerd Font Light Italic";
        font-size = 12;

        # Cursor
        cursor-style = "block";
        cursor-style-blink = false;

        # Window appearance
        background-opacity = 0.8;
        window-padding-x = 0;
        window-padding-y = 0;
        window-padding-balance = true;
        window-padding-color = "extend";

        # Features
        copy-on-select = true;
        shell-integration = "detect";

        # Mouse behavior
        mouse-hide-while-typing = true;

        # Custom shader for cursor trail
        custom-shader = "${config.xdg.configHome}/ghostty/shaders/cursor-trail.glsl";
        custom-shader-animation = true;
      };

      linuxSettings = {
        # GTK / systemd cgroup integration — Linux-only
        gtk-single-instance = true;
        linux-cgroup = "single-instance";
        linux-cgroup-memory-limit = 25769803776; # 24GB limit
        linux-cgroup-processes-limit = 4096;
        linux-cgroup-hard-fail = false;
      };
    in {
      programs.ghostty = {
        enable = true;

        package =
          if isDarwin
          then pkgs.ghostty-bin
          else pkgs.ghostty;

        settings =
          commonSettings
          // (
            if isDarwin
            then {}
            else linuxSettings
          );
      };

      xdg.configFile."ghostty/shaders/cursor-trail.glsl".source = ./cursor-trail.glsl;
    };
  };
}

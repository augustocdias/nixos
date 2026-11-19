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

        # Cursor
        cursor-style = "block";
        cursor-style-blink = false;

        # Window appearance
        # background-opacity = 0.8;
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

        # Mirror herdr-app keys (modules/programs/herdr/herdr.nix). Ctrl+hjkl stays
        # with Neovim: Ghostty cannot hand window-edge movement back like herdr does.
        keybind =
          [
            "alt+h=goto_split:left"
            "alt+j=goto_split:down"
            "alt+k=goto_split:up"
            "alt+l=goto_split:right"
            "alt+m=toggle_split_zoom"
            "ctrl+shift+z=toggle_split_zoom"
            "ctrl+shift+x=close_surface"
            "alt+bracket_left=previous_tab"
            "alt+bracket_right=next_tab"
            "ctrl+shift+r=prompt_tab_title"
            "f2=prompt_tab_title"
          ]
          ++ builtins.genList (i: "ctrl+digit_${toString (i + 1)}=goto_tab:${toString (i + 1)}") 9
          ++ pkgs.lib.optionals (!isDarwin) [
            "super+t=new_tab"
            "super+minus=new_split:down"
            "super+backslash=new_split:right"
          ];
      };

      macSettings = {
        macos-option-as-alt = "left";
        window-step-resize = true;
        auto-update = "off";
        font-size = 12;
        font-family = "MonaspiceNe Nerd Font Mono";
        font-family-italic = "MonaspiceRn Nerd Font Mono";

        font-thicken = true;
        font-thicken-strength = 200;
        alpha-blending = "linear-corrected";
      };

      linuxSettings = {
        font-size = 9;
        font-family = "MonaspiceNe Nerd Font";
        font-family-italic = "MonaspiceRn Nerd Font Light Italic";
        gtk-single-instance = true;
        linux-cgroup = "single-instance";
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
            then macSettings
            else linuxSettings
          );
      };

      xdg.configFile."ghostty/shaders/cursor-trail.glsl".source = ./cursor-trail.glsl;
    };
  };
}

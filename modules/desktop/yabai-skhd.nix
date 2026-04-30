{den, ...}: {
  den.aspects.yabai-skhd = {
    darwin = {...}: {
      services.yabai = {
        enable = true;
        enableScriptingAddition = true;

        config = {
          layout = "bsp";
          window_placement = "second_child";
          auto_balance = "off";
          split_ratio = 0.5;

          top_padding = 8;
          bottom_padding = 8;
          left_padding = 8;
          right_padding = 8;
          window_gap = 8;

          mouse_follows_focus = "off";
          focus_follows_mouse = "autoraise";
          mouse_modifier = "fn";
          mouse_action1 = "move";
          mouse_action2 = "resize";
          mouse_drop_action = "swap";

          window_origin_display = "default";
          window_zoom_persist = "on";
          window_shadow = "float";
          window_animation_duration = 0.0;
          window_opacity_duration = 0.0;
          active_window_opacity = 1.0;
          normal_window_opacity = 1.0;
          window_opacity = "off";
        };

        extraConfig = ''
          # Float common dialog/utility windows
          yabai -m rule --add app="^System Settings$" manage=off
          yabai -m rule --add app="^System Information$" manage=off
          yabai -m rule --add app="^Calculator$" manage=off
          yabai -m rule --add app="^Finder$" title="^Copy" manage=off
          yabai -m rule --add app="^Finder$" title="(Co(py|nnect)|Move|Info|Pref)" manage=off
          yabai -m rule --add app="^1Password" manage=off
          yabai -m rule --add title="^Preferences$" manage=off
        '';
      };

      services.skhd = {
        enable = true;

        skhdConfig = ''
          # ---- Window focus ----
          alt - h : yabai -m window --focus west
          alt - j : yabai -m window --focus south
          alt - k : yabai -m window --focus north
          alt - l : yabai -m window --focus east

          # ---- Move / swap windows ----
          shift + alt - h : yabai -m window --swap west
          shift + alt - j : yabai -m window --swap south
          shift + alt - k : yabai -m window --swap north
          shift + alt - l : yabai -m window --swap east

          # ---- Resize windows ----
          ctrl + alt - h : yabai -m window --resize left:-40:0 || yabai -m window --resize right:-40:0
          ctrl + alt - j : yabai -m window --resize bottom:0:40 || yabai -m window --resize top:0:40
          ctrl + alt - k : yabai -m window --resize top:0:-40   || yabai -m window --resize bottom:0:-40
          ctrl + alt - l : yabai -m window --resize right:40:0  || yabai -m window --resize left:40:0
          ctrl + alt - 0 : yabai -m space --balance

          # ---- Window state ----
          alt - f               : yabai -m window --toggle zoom-fullscreen
          shift + alt - f       : yabai -m window --toggle float --grid 6:6:1:1:4:4
          alt - e               : yabai -m space --rotate 90
          alt - r               : yabai -m space --layout bsp
          shift + alt - r       : yabai -m space --layout float
          alt - t               : yabai -m window --toggle split

          # ---- Close window ----
          alt - q : yabai -m window --close

          # ---- Workspace (Space) navigation: alt+1..9 ----
          alt - 1 : yabai -m space --focus 1
          alt - 2 : yabai -m space --focus 2
          alt - 3 : yabai -m space --focus 3
          alt - 4 : yabai -m space --focus 4
          alt - 5 : yabai -m space --focus 5
          alt - 6 : yabai -m space --focus 6
          alt - 7 : yabai -m space --focus 7
          alt - 8 : yabai -m space --focus 8
          alt - 9 : yabai -m space --focus 9

          # Send window to space + follow
          shift + alt - 1 : yabai -m window --space 1 ; yabai -m space --focus 1
          shift + alt - 2 : yabai -m window --space 2 ; yabai -m space --focus 2
          shift + alt - 3 : yabai -m window --space 3 ; yabai -m space --focus 3
          shift + alt - 4 : yabai -m window --space 4 ; yabai -m space --focus 4
          shift + alt - 5 : yabai -m window --space 5 ; yabai -m space --focus 5
          shift + alt - 6 : yabai -m window --space 6 ; yabai -m space --focus 6
          shift + alt - 7 : yabai -m window --space 7 ; yabai -m space --focus 7
          shift + alt - 8 : yabai -m window --space 8 ; yabai -m space --focus 8
          shift + alt - 9 : yabai -m window --space 9 ; yabai -m space --focus 9

          # ---- App launching ----
          alt - return : open -na Ghostty
          alt - b      : open -na "1Password"
        '';
      };
    };
  };
}

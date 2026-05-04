{
  den,
  inputs,
  lib,
  ...
}: {
  flake-file.inputs.hyprland.url = lib.mkDefault "github:hyprwm/Hyprland";

  den.aspects.hyprland = {
    nixos = {
      imports = lib.optionals (inputs ? hyprland) [inputs.hyprland.nixosModules.default];

      programs = {
        hyprland = {
          enable = true;
          withUWSM = true;
          xwayland.enable = true;
        };
        dconf.enable = true;
        gpu-screen-recorder.enable = true;
      };

      environment.sessionVariables = {
        WLR_NO_HARDWARE_CURSORS = "1";
        NIXOS_OZONE_WL = "1";
      };
    };

    homeManager = {pkgs, ...}: {
      wayland.windowManager.hyprland = {
        enable = true;

        systemd.enable = true;
        systemd.variables = ["all"];

        settings = {
          monitor = [
            "eDP-1,3072x1920@120,auto,1.5"
            ",preferred,auto,1"
          ];

          workspace = [
            "1, monitor:eDP-1, default:true"
            "2, monitor:eDP-1"
            "3, monitor:eDP-1"
            "4, monitor:eDP-1"
            "5, monitor:eDP-1, layout:scrolling"
            "6, monitor:DP-1, default:true"
            "7, monitor:DP-1"
            "8, monitor:DP-1"
            "9, monitor:DP-1"
            "10, monitor:DP-1"
          ];

          exec-once = [
            "uwsm app -- slack"
            "uwsm app -- thunderbird"
            "uwsm app -- lotion"
            "uwsm app -- ghostty --class=ghostty-startup +new-window"
            "hyprctl dispatch workspace 7 && uwsm app -- firefox"
            "uwsm app -- datagrip"
            "uwsm app -- virt-manager"
            "uwsm app -- firefoxpwa site launch 01KKC8KPKEX5XZPBBK02D5ZM67"
            "uwsm app -- cider-2"
          ];

          env = [
            "XCURSOR_SIZE,24"
            "XCURSOR_THEME,catppuccin-mocha-blue-cursors"
            "QT_QPA_PLATFORMTHEME,qt6ct"
            "QT_QUICK_CONTROLS_STYLE,org.hyprland.style"
          ];

          general = {
            gaps_in = 5;
            gaps_out = 5;
            border_size = 2;
            "col.active_border" = "rgba(89b4faee) rgba(94e2d5ee) 45deg";
            "col.inactive_border" = "rgba(585b70aa)";
            layout = "dwindle";
            allow_tearing = false;
          };

          decoration = {
            rounding = 8;
            blur = {
              enabled = true;
              size = 3;
              passes = 1;
            };
            shadow = {
              enabled = true;
              range = 4;
              render_power = 3;
              color = "rgba(11111bee)";
            };
          };

          animations = {
            enabled = true;
            bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
            animation = [
              "windows, 1, 7, myBezier"
              "windowsOut, 1, 7, default, popin 80%"
              "border, 1, 10, default"
              "borderangle, 1, 8, default"
              "fade, 1, 7, default"
              "workspaces, 1, 6, default"
            ];
          };

          dwindle = {
            pseudotile = true;
            preserve_split = true;
            force_split = 2;
          };

          master.new_status = "master";

          scrolling = {
            column_width = 0.5;
            direction = "right";
            focus_fit_method = 1;
          };

          cursor.no_warps = true;
          misc.focus_on_activate = true;

          gestures.gesture = [
            "3, horizontal, workspace"
          ];

          input = {
            kb_layout = "eu";
            follow_mouse = 1;
            accel_profile = "flat";
            sensitivity = 1;
            touchpad = {
              natural_scroll = true;
              tap-to-click = true;
              disable_while_typing = true;
              clickfinger_behavior = true;
              scroll_factor = 0.3;
            };
          };

          "$mainMod" = "SUPER";

          bind = [
            "$mainMod, RETURN, exec, ghostty +new-window"
            "$mainMod, SPACE, exec, dms ipc call launcher toggle"
            "$mainMod, Q, killactive,"
            "$mainMod SHIFT, SPACE, exec, dms ipc call powermenu toggle"
            "$mainMod, A, exec, dms ipc call plugins toggle aiAssistant"

            ", PRINT, exec, dms screenshot --no-file"
            "SHIFT, PRINT, exec, dms screenshot full --no-file"
            "$mainMod, PRINT, exec, dms screenshot --no-clipboard -d ~/pictures/screenshots"
            "$mainMod SHIFT, 4, exec, dms screenshot --no-file"
            "$mainMod SHIFT, 3, exec, dms screenshot full --no-file"
            "$mainMod SHIFT, 5, exec, dms screenshot --no-clipboard -d ~/pictures/screenshots"

            "$mainMod SHIFT, R, exec, dms ipc call screenRecorder startRecording"
            "$mainMod SHIFT CTRL, R, exec, stop-recording"

            "$mainMod SHIFT, L, exec, dms ipc call lock lock"

            ", XF86AudioPlay, exec, dms ipc call mpris playPause"
            ", XF86AudioPause, exec, dms ipc call mpris playPause"
            ", XF86AudioPrev, exec, dms ipc call mpris previous"
            ", XF86AudioNext, exec, dms ipc call mpris next"
            ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
            ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
            ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"

            "$mainMod ALT, J, movefocus, d"
            "$mainMod ALT, K, movefocus, u"
            "$mainMod ALT, H, movefocus, l"
            "$mainMod ALT, L, movefocus, r"

            "$mainMod CTRL ALT, H, focusmonitor, -1"
            "$mainMod CTRL ALT, L, focusmonitor, +1"

            "$mainMod, TAB, workspace, previous"

            "ALT, TAB, cyclenext, , , currentworkspace"
            "ALT, TAB, alterzorder, top"
            "ALT SHIFT, TAB, cyclenext, prev, , currentworkspace"
            "ALT SHIFT, TAB, alterzorder, top"

            "$mainMod CTRL ALT, R, layoutmsg, orientationnext"
            "$mainMod CTRL ALT, T, togglefloating,"
            "$mainMod CTRL ALT, T, centerwindow,"

            "$mainMod CTRL ALT, RETURN, fullscreen, 1"
            "$mainMod SHIFT ALT, RETURN, fullscreen, 0"

            "$mainMod CTRL, J, swapwindow, d"
            "$mainMod CTRL, K, swapwindow, u"
            "$mainMod CTRL, H, swapwindow, l"
            "$mainMod CTRL, L, swapwindow, r"

            "$mainMod SHIFT ALT, H, movewindow, mon:-1"
            "$mainMod SHIFT ALT, H, focusmonitor, -1"
            "$mainMod SHIFT ALT, L, movewindow, mon:+1"
            "$mainMod SHIFT ALT, L, focusmonitor, +1"

            "$mainMod ALT, P, movetoworkspace, -1"
            "$mainMod ALT, N, movetoworkspace, +1"

            "$mainMod CTRL, 1, movetoworkspacesilent, 1"
            "$mainMod CTRL, 2, movetoworkspacesilent, 2"
            "$mainMod CTRL, 3, movetoworkspacesilent, 3"
            "$mainMod CTRL, 4, movetoworkspacesilent, 4"
            "$mainMod CTRL, 5, movetoworkspacesilent, 5"
            "$mainMod CTRL, 6, movetoworkspacesilent, 6"
            "$mainMod CTRL, 7, movetoworkspacesilent, 7"
            "$mainMod CTRL, 8, movetoworkspacesilent, 8"
            "$mainMod CTRL, 9, movetoworkspacesilent, 9"
            "$mainMod CTRL, 0, movetoworkspacesilent, 10"

            "$mainMod, 1, workspace, 1"
            "$mainMod, 2, workspace, 2"
            "$mainMod, 3, workspace, 3"
            "$mainMod, 4, workspace, 4"
            "$mainMod, 5, workspace, 5"
            "$mainMod, 6, workspace, 6"
            "$mainMod, 7, workspace, 7"
            "$mainMod, 8, workspace, 8"
            "$mainMod, 9, workspace, 9"
            "$mainMod, 0, workspace, 10"

            "$mainMod, mouse_down, workspace, e+1"
            "$mainMod, mouse_up, workspace, e-1"
            "$mainMod, L, workspace, e+1"
            "$mainMod, H, workspace, e-1"

            "$mainMod, grave, togglespecialworkspace, scratchpad"
            "$mainMod SHIFT, grave, movetoworkspace, special:scratchpad"
            "$mainMod SHIFT, N, workspace, empty"

            "$mainMod SHIFT CTRL ALT, R, exec, hyprctl reload"

            "$mainMod ALT, mouse_down, layoutmsg, move +col"
            "$mainMod ALT, mouse_up, layoutmsg, move -col"
            "$mainMod ALT, period, layoutmsg, move +col"
            "$mainMod ALT, comma, layoutmsg, move -col"
          ];

          binde = [
            ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
            ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
            ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
            ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
          ];

          bindm = [
            "$mainMod, mouse:272, movewindow"
            "$mainMod, mouse:273, resizewindow"
          ];

          windowrule = [
            "workspace 1 silent, match:class ^(Slack)$"
            "workspace 2 silent, match:class ^(thunderbird)$"
            "workspace 3 silent, match:class ^(Lotion)$"
            "workspace 6 silent, match:class ^(ghostty-startup)$"
            "workspace 8 silent, match:class ^(jetbrains-datagrip)$"
            "workspace 9 silent, match:class ^(\\.virt-manager-wrapped)$"
            "workspace 5 silent, match:class ^(FFPWA-01KKC8KPKEX5XZPBBK02D5ZM67)$"
            "workspace 5 silent, match:class ^(Cider)$"

            "float on, match:class ^(pavucontrol)$"
            "float on, match:class ^(nm-connection-editor)$"
            "float on, match:title ^(Picture-in-Picture)$"
            "pin on, match:title ^(Picture-in-Picture)$"

            "opacity 0.95 0.95, match:class ^(wezterm)$"
            "opacity 0.9 0.9, match:class ^(Code)$"

            "size 640 360, match:title ^(Picture-in-Picture)$"
            "move monitor_w-660 monitor_h-380, match:title ^(Picture-in-Picture)$"
          ];
        };

        extraConfig = ''
          bind = $mainMod ALT, r, submap, resize

          submap = resize

          binde = , l, resizeactive, 10 0
          binde = , h, resizeactive, -10 0
          binde = , k, resizeactive, 0 -10
          binde = , j, resizeactive, 0 10

          binde = SHIFT, l, resizeactive, 5 0
          binde = SHIFT, h, resizeactive, -5 0
          binde = SHIFT, k, resizeactive, 0 -5
          binde = SHIFT, j, resizeactive, 0 5

          bind = , Shift_L, exec,
          bind = , Shift_R, exec,

          bind = , escape, submap, reset
          bind = , catchall, submap, reset

          submap = reset
        '';
      };

      home.pointerCursor = {
        name = "catppuccin-mocha-blue-cursors";
        package = pkgs.catppuccin-cursors.mochaBlue;
        size = 24;
        gtk.enable = true;
        x11.enable = true;
      };

      home.packages = with pkgs; [
        brightnessctl
        playerctl
        wl-clipboard
        wl-clip-persist
        mpvpaper

        hyprland-qt-support
        hyprland-qtutils
        hyprpwcenter

        libsForQt5.qt5ct
        kdePackages.qt6ct
        adw-gtk3
      ];

      systemd.user.services.wl-clip-persist = {
        Unit = {
          Description = "Persistent clipboard for Wayland";
          PartOf = ["graphical-session.target"];
          After = ["graphical-session.target"];
        };
        Service = {
          ExecStart = "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard both";
          Restart = "on-failure";
          RestartSec = 1;
        };
        Install.WantedBy = ["graphical-session.target"];
      };
    };
  };
}

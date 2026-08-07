{
  den,
  inputs,
  lib,
  ...
}: let
  inherit (lib.generators) mkLuaInline;

  mod = "SUPER";

  bind = keys: dsp: {_args = [keys (mkLuaInline dsp)];};
  bindOpts = keys: dsp: opts: {_args = [keys (mkLuaInline dsp) opts];};
  binde = keys: dsp: bindOpts keys dsp {repeating = true;};

  # dispatcher helpers
  exec = cmd: ''hl.dsp.exec_cmd("${cmd}")'';
  focusDir = d: ''hl.dsp.focus({ direction = "${d}" })'';
  focusMon = m: ''hl.dsp.focus({ monitor = "${m}" })'';
  focusWs = w: ''hl.dsp.focus({ workspace = "${w}" })'';
  swapDir = d: ''hl.dsp.window.swap({ direction = "${d}" })'';
  moveWs = w: ''hl.dsp.window.move({ workspace = "${w}" })'';
  moveWsSilent = w: ''hl.dsp.window.move({ workspace = "${w}", follow = false })'';
  moveMon = m: ''hl.dsp.window.move({ monitor = "${m}" })'';
  layoutMsg = m: ''hl.dsp.layout("${m}")'';

  resizeRel = x: y: ''hl.dsp.window.resize({ x = ${x}, y = ${y}, relative = true })'';

  resizeSubmap = ''
    function()
      hl.bind("l", ${resizeRel "10" "0"}, { repeating = true })
      hl.bind("h", ${resizeRel "-10" "0"}, { repeating = true })
      hl.bind("k", ${resizeRel "0" "-10"}, { repeating = true })
      hl.bind("j", ${resizeRel "0" "10"}, { repeating = true })

      hl.bind("SHIFT + l", ${resizeRel "5" "0"}, { repeating = true })
      hl.bind("SHIFT + h", ${resizeRel "-5" "0"}, { repeating = true })
      hl.bind("SHIFT + k", ${resizeRel "0" "-5"}, { repeating = true })
      hl.bind("SHIFT + j", ${resizeRel "0" "5"}, { repeating = true })

      -- swallow bare shift presses so they don't fall through to catchall
      hl.bind("Shift_L", hl.dsp.no_op())
      hl.bind("Shift_R", hl.dsp.no_op())

      hl.bind("escape", hl.dsp.submap("reset"))
      hl.bind("catchall", hl.dsp.submap("reset"))
    end
  '';

  autostart = [
    "uwsm app -- slack"
    "uwsm app -- thunderbird"
    "uwsm app -- lotion"
    "uwsm app -- datagrip"
    "uwsm app -- virt-manager"
    "uwsm app -- firefoxpwa site launch 01KKC8KPKEX5XZPBBK02D5ZM67"
    "uwsm app -- cider-2 --ozone-platform=wayland"
  ];

  startupHook = ''
    function()
    ${lib.concatMapStrings (c: "  hl.exec_cmd(\"${c}\")\n") autostart}end
  '';

  wsRule = ws: monitor: extra: {workspace = ws;} // {inherit monitor;} // extra;
in {
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
        NIXOS_OZONE_WL = "1";
        # ccs is broken in hyprland portal apparently
        INTEL_DEBUG = "noccs";
        AQ_NO_MODIFIERS = "1";
      };
    };

    homeManager = {
      pkgs,
      config,
      ...
    }: {
      xdg.configFile."uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
      wayland.windowManager.hyprland = {
        enable = true;

        # only enable if UWSM is disabled
        systemd.enable = false;

        settings = {
          curve = {
            _args = [
              "myBezier"
              {
                type = "bezier";
                points = [
                  [0.05 0.9]
                  [0.1 1.05]
                ];
              }
            ];
          };

          config = {
            xwayland.force_zero_scaling = true;

            general = {
              gaps_in = 5;
              gaps_out = 5;
              border_size = 2;
              col = {
                active_border = {
                  colors = ["rgba(89b4faee)" "rgba(94e2d5ee)"];
                  angle = 45;
                };
                inactive_border = "rgba(585b70aa)";
              };
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

            animations.enabled = true;

            dwindle = {
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

            input = {
              kb_layout = "eu";
              follow_mouse = 1;
              accel_profile = "flat";
              sensitivity = 1;
              touchpad = {
                natural_scroll = true;
                tap_to_click = true;
                disable_while_typing = true;
                clickfinger_behavior = true;
                scroll_factor = 0.3;
              };
            };
          };

          monitor = [
            {
              output = "eDP-1";
              mode = "3072x1920@120";
              position = "auto";
              scale = 1.5;
            }
            {
              output = "";
              mode = "preferred";
              position = "auto";
              scale = 1;
            }
          ];

          workspace_rule = [
            (wsRule "1" "eDP-1" {default = true;})
            (wsRule "2" "eDP-1" {})
            (wsRule "3" "eDP-1" {})
            (wsRule "4" "eDP-1" {})
            (wsRule "5" "eDP-1" {layout = "scrolling";})
            (wsRule "6" "DP-1" {default = true;})
            (wsRule "7" "DP-1" {})
            (wsRule "8" "DP-1" {})
            (wsRule "9" "DP-1" {})
            (wsRule "10" "DP-1" {})
          ];

          env = [
            {_args = ["XCURSOR_SIZE" "24"];}
            {_args = ["XCURSOR_THEME" "catppuccin-mocha-blue-cursors"];}
            {_args = ["QT_QPA_PLATFORMTHEME" "qt6ct"];}
            {_args = ["QT_QUICK_CONTROLS_STYLE" "org.hyprland.style"];}
            # ccs is broken in hyprland portal apparently
            {_args = ["INTEL_DEBUG" "noccs"];}
            {_args = ["AQ_NO_MODIFIERS" "1"];}
          ];

          animation = [
            {
              leaf = "windows";
              enabled = true;
              speed = 7;
              bezier = "myBezier";
            }
            {
              leaf = "windowsOut";
              enabled = true;
              speed = 7;
              bezier = "default";
              style = "popin 80%";
            }
            {
              leaf = "border";
              enabled = true;
              speed = 10;
              bezier = "default";
            }
            {
              leaf = "borderangle";
              enabled = true;
              speed = 8;
              bezier = "default";
            }
            {
              leaf = "fade";
              enabled = true;
              speed = 7;
              bezier = "default";
            }
            {
              leaf = "workspaces";
              enabled = true;
              speed = 6;
              bezier = "default";
            }
          ];

          gesture = {
            fingers = 3;
            direction = "horizontal";
            action = "workspace";
          };

          window_rule = [
            {
              name = "ws-slack";
              match.class = "(?i)slack";
              workspace = "1 silent";
            }
            {
              name = "ws-thunderbird";
              match.class = "^(thunderbird)$";
              workspace = "2 silent";
            }
            {
              name = "ws-dankcalendar";
              match.class = "^(com\\.danklinux\\.dankcalendar)$";
              workspace = "3 silent";
            }
            {
              name = "ws-lotion";
              match.class = "^(Lotion)$";
              workspace = "4 silent";
            }
            {
              name = "ws-ffpwa";
              match.class = "^(FFPWA-01KKC8KPKEX5XZPBBK02D5ZM67)$";
              workspace = "5 silent";
            }
            {
              name = "ws-cider";
              match.class = "(?i)cider";
              workspace = "5 silent";
            }
            {
              name = "ws-datagrip";
              match.class = "^(jetbrains-datagrip)$";
              workspace = "8 silent";
            }
            {
              name = "ws-virt-manager";
              match.class = "^(\\.virt-manager-wrapped)$";
              workspace = "9 silent";
            }

            {
              name = "float-pavucontrol";
              match.class = "^(pavucontrol)$";
              float = true;
            }
            {
              name = "float-nm-connection-editor";
              match.class = "^(nm-connection-editor)$";
              float = true;
            }
            {
              name = "picture-in-picture";
              match.title = "^(Picture-in-Picture)$";
              float = true;
              pin = true;
              size = "640 360";
              move = "monitor_w-660 monitor_h-380";
            }

            {
              name = "opacity-wezterm";
              match.class = "^(wezterm)$";
              opacity = "0.95 0.95";
            }
            {
              name = "opacity-code";
              match.class = "^(Code)$";
              opacity = "0.9 0.9";
            }
          ];

          bind = [
            (bind "${mod} + RETURN" (exec "ghostty +new-window"))
            (bind "${mod} + SPACE" (exec "dms ipc call launcher toggle"))
            (bind "${mod} + Q" "hl.dsp.window.close()")
            (bind "${mod} + SHIFT + SPACE" (exec "dms ipc call powermenu toggle"))
            (bind "${mod} + A" (exec "dms ipc call plugins toggle aiAssistant"))

            (bind "PRINT" (exec "dms screenshot --no-file"))
            (bind "SHIFT + PRINT" (exec "dms screenshot full --no-file"))
            (bind "${mod} + PRINT" (exec "dms screenshot --no-clipboard -d ~/pictures/screenshots"))
            (bind "${mod} + SHIFT + 4" (exec "dms screenshot --no-file"))
            (bind "${mod} + SHIFT + 3" (exec "dms screenshot full --no-file"))
            (bind "${mod} + SHIFT + 5" (exec "dms screenshot --no-clipboard -d ~/pictures/screenshots"))

            (bind "${mod} + R" (exec "dms ipc call screenCaptureToolbar toggle"))

            (bind "${mod} + SHIFT + L" (exec "dms ipc call lock lock"))

            (bind "XF86AudioPlay" (exec "dms ipc call mpris playPause"))
            (bind "XF86AudioPause" (exec "dms ipc call mpris playPause"))
            (bind "XF86AudioPrev" (exec "dms ipc call mpris previous"))
            (bind "XF86AudioNext" (exec "dms ipc call mpris next"))
            (bind "XF86AudioMute" (exec "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
            (bind "XF86MonBrightnessUp" (exec "brightnessctl set 5%+"))
            (bind "XF86MonBrightnessDown" (exec "brightnessctl set 5%-"))

            (bind "${mod} + ALT + J" (focusDir "down"))
            (bind "${mod} + ALT + K" (focusDir "up"))
            (bind "${mod} + ALT + H" (focusDir "left"))
            (bind "${mod} + ALT + L" (focusDir "right"))

            (bind "${mod} + CTRL + ALT + H" (focusMon "-1"))
            (bind "${mod} + CTRL + ALT + L" (focusMon "+1"))

            (bind "${mod} + TAB" (focusWs "previous"))

            (bind "ALT + TAB" "hl.dsp.window.cycle_next({ next = true })")
            (bind "ALT + TAB" ''hl.dsp.window.alter_zorder({ mode = "top" })'')
            (bind "ALT + SHIFT + TAB" "hl.dsp.window.cycle_next({ next = false })")
            (bind "ALT + SHIFT + TAB" ''hl.dsp.window.alter_zorder({ mode = "top" })'')

            (bind "${mod} + CTRL + ALT + R" (layoutMsg "orientationnext"))
            (bind "${mod} + CTRL + ALT + T" ''hl.dsp.window.float({ action = "toggle" })'')
            (bind "${mod} + CTRL + ALT + T" "hl.dsp.window.center()")

            (bind "${mod} + CTRL + ALT + RETURN" ''hl.dsp.window.fullscreen({ mode = "maximized" })'')
            (bind "${mod} + SHIFT + ALT + RETURN" ''hl.dsp.window.fullscreen({ mode = "fullscreen" })'')

            (bind "${mod} + CTRL + J" (swapDir "down"))
            (bind "${mod} + CTRL + K" (swapDir "up"))
            (bind "${mod} + CTRL + H" (swapDir "left"))
            (bind "${mod} + CTRL + L" (swapDir "right"))

            (bind "${mod} + SHIFT + ALT + H" (moveMon "-1"))
            (bind "${mod} + SHIFT + ALT + H" (focusMon "-1"))
            (bind "${mod} + SHIFT + ALT + L" (moveMon "+1"))
            (bind "${mod} + SHIFT + ALT + L" (focusMon "+1"))

            (bind "${mod} + ALT + P" (moveWs "-1"))
            (bind "${mod} + ALT + N" (moveWs "+1"))

            (bind "${mod} + CTRL + 1" (moveWsSilent "1"))
            (bind "${mod} + CTRL + 2" (moveWsSilent "2"))
            (bind "${mod} + CTRL + 3" (moveWsSilent "3"))
            (bind "${mod} + CTRL + 4" (moveWsSilent "4"))
            (bind "${mod} + CTRL + 5" (moveWsSilent "5"))
            (bind "${mod} + CTRL + 6" (moveWsSilent "6"))
            (bind "${mod} + CTRL + 7" (moveWsSilent "7"))
            (bind "${mod} + CTRL + 8" (moveWsSilent "8"))
            (bind "${mod} + CTRL + 9" (moveWsSilent "9"))
            (bind "${mod} + CTRL + 0" (moveWsSilent "10"))

            (bind "${mod} + 1" (focusWs "1"))
            (bind "${mod} + 2" (focusWs "2"))
            (bind "${mod} + 3" (focusWs "3"))
            (bind "${mod} + 4" (focusWs "4"))
            (bind "${mod} + 5" (focusWs "5"))
            (bind "${mod} + 6" (focusWs "6"))
            (bind "${mod} + 7" (focusWs "7"))
            (bind "${mod} + 8" (focusWs "8"))
            (bind "${mod} + 9" (focusWs "9"))
            (bind "${mod} + 0" (focusWs "10"))

            (bind "${mod} + mouse_down" (focusWs "e+1"))
            (bind "${mod} + mouse_up" (focusWs "e-1"))
            (bind "${mod} + L" (focusWs "e+1"))
            (bind "${mod} + H" (focusWs "e-1"))

            (bind "${mod} + grave" ''hl.dsp.workspace.toggle_special("scratchpad")'')
            (bind "${mod} + SHIFT + grave" (moveWs "special:scratchpad"))
            (bind "${mod} + SHIFT + N" (focusWs "empty"))

            (bind "${mod} + SHIFT + CTRL + ALT + R" (exec "hyprctl reload"))

            (bind "${mod} + ALT + mouse_down" (layoutMsg "move +col"))
            (bind "${mod} + ALT + mouse_up" (layoutMsg "move -col"))
            (bind "${mod} + ALT + period" (layoutMsg "move +col"))
            (bind "${mod} + ALT + comma" (layoutMsg "move -col"))

            # hyprlang `binde` -> { repeating = true }
            (binde "XF86AudioRaiseVolume" (exec "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
            (binde "XF86AudioLowerVolume" (exec "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
            (binde "XF86MonBrightnessUp" (exec "brightnessctl set 5%+"))
            (binde "XF86MonBrightnessDown" (exec "brightnessctl set 5%-"))

            # hyprlang `bindm` -> the mouse dispatchers themselves
            (bind "${mod} + mouse:272" "hl.dsp.window.drag()")
            (bind "${mod} + mouse:273" "hl.dsp.window.resize()")

            # submap entry
            (bind "${mod} + ALT + R" ''hl.dsp.submap("resize")'')
          ];

          # hl.define_submap(name, fn)
          define_submap = {
            _args = [
              "resize"
              (mkLuaInline resizeSubmap)
            ];
          };

          on = {
            _args = [
              "hyprland.start"
              (mkLuaInline startupHook)
            ];
          };
        };
      };

      home.pointerCursor = {
        enable = true;
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

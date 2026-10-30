{
  den,
  inputs,
  lib,
  ...
}: {
  flake-file.inputs.dms = {
    url = lib.mkDefault "github:duxlabs-dev/dux-shell";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  flake-file.inputs.dms-plugins = {
    url = lib.mkDefault "github:duxlabs-dev/dux-plugin-registry";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  flake-file.inputs.dankcalendar = {
    url = lib.mkDefault "github:duxlabs-dev/dux-calendar";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  flake-file.inputs.dank-pinentry = {
    url = lib.mkDefault "github:augustocdias/dank-pinentry";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  flake-file.inputs.dank-greeter = {
    url = lib.mkDefault "github:duxlabs-dev/dux-greeter";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.dms = {
    nixos = {
      pkgs,
      config,
      ...
    }: {
      imports = lib.optionals (inputs ? dank-greeter) [inputs.dank-greeter.nixosModules.default];

      # khal (pulled in by enableCalendarEvents) 0.14.1's sphinx man build no
      # longer lands in $man; drop once nixpkgs fixes it
      nixpkgs.overlays = [
        (final: prev: {
          khal = prev.khal.overridePythonAttrs {
            outputs = ["out" "doc"];
            sphinxBuilders = ["html"];
          };
        })
      ];

      qt.enable = true;
      programs.kdeconnect.enable = true;

      users.users.augusto.extraGroups = ["greeter"];

      programs.dms-greeter = {
        enable = true;
        compositor.name = "hyprland";
        # Hyprland 0.56 parses every config as Lua. dms-greeter picks its
        # template via launcher.isHyprlandLuaConfig, which sniffs the custom
        # config for `hl.` -- so writing Lua here also makes the greeter append
        # its own quickshell launch as `hl.on("hyprland.start", ...)` instead of
        # a hyprlang `exec-once` line.
        compositor.customConfig = ''
          hl.env("XCURSOR_SIZE", "24")
          hl.env("XCURSOR_THEME", "catppuccin-mocha-blue-cursors")

          hl.on("hyprland.start", function()
            hl.exec_cmd("hyprctl setcursor catppuccin-mocha-blue-cursors 24")
          end)
        '';
        configHome = config.users.users.augusto.home;
      };

      # DMS lock screen runs fingerprint and U2F as separate parallel PAM sessions,
      # so the password session must NOT include them or they'll block sequentially.
      security.pam.services.dankshell = {
        u2fAuth = false;
        fprintAuth = false;
      };

      environment.systemPackages = [
        pkgs.catppuccin-cursors.mochaBlue
        pkgs.papirus-icon-theme
      ];
    };

    homeManager = {
      pkgs,
      config,
      ...
    }: {
      imports =
        lib.optionals (inputs ? dms) [inputs.dms.homeModules.dank-material-shell]
        ++ lib.optionals (inputs ? dms-plugins) [inputs.dms-plugins.homeModules.default]
        ++ lib.optionals (inputs ? dankcalendar) [inputs.dankcalendar.homeModules.default]
        ++ lib.optionals (inputs ? dank-pinentry) [inputs.dank-pinentry.homeModules.default];

      programs.dank-pinentry = {
        enable = true;
        installPlugin = false;
      };

      xsession.preferStatusNotifierItems = true;

      programs.dank-material-shell = {
        enable = true;
        systemd.enable = true;

        enableSystemMonitoring = true;
        enableVPN = true;
        enableDynamicTheming = true;
        enableAudioWavelength = true;
        enableCalendarEvents = true;
        enableClipboardPaste = true;

        settings = {
          lockScreenWidgetInstances = [
            {
              config = {
                autoPosition = true;
                colorMode = "default";
                customColor = "#ffffff";
                displayPreferences = [
                  "all"
                ];
                showAnalogNumbers = false;
                showAnalogSeconds = true;
                showDate = false;
                showDigitalSeconds = false;
                style = "expressive";
                syncPositionAcrossScreens = true;
                transparency = 0;
                twoTone = true;
                weight = 0;
              };
              enabled = true;
              id = "lock_clock";
              widgetType = "desktopClock";
            }
            {
              config = {
                colorMode = "default";
                customColor = "#ffffff";
                displayPreferences = [
                  "all"
                ];
                format = "short";
                syncPositionAcrossScreens = true;
              };
              enabled = true;
              id = "lock_date";
              widgetType = "lockDate";
            }
            {
              config = {
                displayPreferences = [
                  "all"
                ];
                passwordVisibility = "always";
                profileVisibility = "always";
                style = "expressive";
                syncPositionAcrossScreens = true;
              };
              enabled = true;
              id = "lock_auth";
              widgetType = "lockAuth";
            }
            {
              config = {
                displayPreferences = [
                  "all"
                ];
                mode = 2;
                syncPositionAcrossScreens = true;
              };
              enabled = false;
              id = "lock_notifications";
              widgetType = "lockNotifications";
            }
            {
              config = {
                background = false;
                displayPreferences = [
                  "all"
                ];
                showMediaPlayer = true;
                showWeather = true;
                syncPositionAcrossScreens = true;
              };
              enabled = true;
              id = "lock_status";
              widgetType = "lockStatus";
            }
            {
              config = {
                displayPreferences = [
                  "all"
                ];
                shape = "round";
                syncPositionAcrossScreens = true;
              };
              enabled = true;
              id = "lock_power";
              widgetType = "lockPower";
            }
          ];
          greeterWidgetInstances = [
            {
              config = {
                autoPosition = true;
                colorMode = "default";
                customColor = "#ffffff";
                displayPreferences = [
                  "all"
                ];
                showAnalogNumbers = false;
                showAnalogSeconds = true;
                showDate = false;
                showDigitalSeconds = false;
                style = "expressive";
                syncPositionAcrossScreens = true;
                transparency = 0;
                twoTone = true;
                weight = 0;
              };
              enabled = true;
              id = "lock_clock";
              widgetType = "desktopClock";
            }
            {
              config = {
                colorMode = "default";
                customColor = "#ffffff";
                displayPreferences = [
                  "all"
                ];
                format = "short";
                syncPositionAcrossScreens = true;
              };
              enabled = true;
              id = "lock_date";
              widgetType = "lockDate";
            }
            {
              config = {
                displayPreferences = [
                  "all"
                ];
                passwordVisibility = "always";
                profileVisibility = "always";
                style = "expressive";
                syncPositionAcrossScreens = true;
              };
              enabled = true;
              id = "lock_auth";
              widgetType = "lockAuth";
            }
            {
              config = {
                background = false;
                displayPreferences = [
                  "all"
                ];
                showMediaPlayer = true;
                showWeather = true;
                syncPositionAcrossScreens = true;
              };
              enabled = true;
              id = "lock_status";
              widgetType = "lockStatus";
            }
            {
              config = {
                displayPreferences = [
                  "all"
                ];
                shape = "round";
                syncPositionAcrossScreens = true;
              };
              enabled = true;
              id = "lock_power";
              widgetType = "lockPower";
            }
            {
              config = {
                displayPreferences = [
                  "all"
                ];
                syncPositionAcrossScreens = true;
              };
              enabled = true;
              id = "greeter_session";
              widgetType = "greeterSession";
            }
          ];
          displayNameMode = "system";
          currentThemeName = "custom";
          customThemeFile = "/home/augusto/.config/DankMaterialShell/themes/catppuccin/theme.json";
          registryThemeVariants = {
            catppuccin = {
              accent = "blue";
              flavor = "mocha";
            };
          };
          radiusStrength = 20;
          radiusMode = "scale";
          fixedRadius = 16;
          clockFormat = "24h";
          showSeconds = false;
          useFahrenheit = false;
          wallpaperFillMode = "Fill";
          greeterEnableFprint = true;
          greeterEnableU2f = true;
          useAutoLocation = true;
          weatherEnabled = true;
          fontFamily = "Inter Variable";
          monoFontFamily = "MonaspiceRn Nerd Font Mono";
          fontWeight = 400;
          fontScale = 1;
          lockScreenShowPowerActions = true;
          lockScreenShowProfileImage = true;
          powerActionConfirm = true;
          powerActionHoldDuration = 0.5;
          powerMenuActions = [
            "reboot"
            "logout"
            "poweroff"
            "lock"
            "suspend"
            "restart"
          ];
          powerMenuDefaultAction = "logout";
          powerMenuGridLayout = false;
          dockConfigs = [
            {
              id = "dock";
              name = "Dock";
              enabled = false;
              screenPreferences = [
                "all"
              ];
              showOnLastDisplay = true;
              position = 1;
              mode = "compact";
              taskbarAlign = "center";
              widgetExpansion = "popout";
              iconSize = 40;
              spacing = 4;
              itemSpacing = 4;
              margin = 0;
              bottomGap = 0;
              transparency = 1;
              followInterfaceStyle = true;
              autoHide = false;
              smartAutoHide = false;
              useOverlayLayer = false;
              editOnRightClick = false;
              showOnFullscreen = false;
              openOnOverview = false;
              groupByApp = false;
              separatePinnedAndRunningApps = false;
              restoreSpecialWorkspaceOnClick = false;
              isolateDisplays = false;
              indicatorStyle = "circle";
              borderEnabled = false;
              borderColor = "surfaceText";
              borderOpacity = 1;
              borderThickness = 1;
              launcherEnabled = false;
              launcherLogoMode = "apps";
              launcherLogoCustomPath = "";
              launcherLogoColorOverride = "";
              launcherLogoSizeOffset = 0;
              launcherLogoBrightness = 0.5;
              launcherLogoContrast = 1;
              maxVisibleApps = 0;
              maxVisibleRunningApps = 0;
              showOverflowBadge = true;
              showTrash = false;
              trashFileManager = "default";
              trashCustomCommand = "";
              magnification = false;
              magnificationScale = 130;
              magnificationProfile = "parabolic";
              magnificationExpand = false;
              order = [];
              widgets = [
                {
                  enabled = true;
                  id = "dock_launcher";
                  widgetId = "dockLauncher";
                }
                {
                  enabled = true;
                  id = "dock_apps";
                  widgetId = "appsDock";
                }
                {
                  enabled = true;
                  id = "dock_trash";
                  widgetId = "dockTrash";
                }
              ];
            }
          ];
          currentThemeCategory = "registry";
          matugenScheme = "scheme-tonal-spot";
          runUserMatugenTemplates = true;
          popupTransparency = 1;
          dmsWindowsFloatingSeeded = [
            "hyprland"
          ];
          widgetBackgroundColor = "s";
          widgetColorMode = "default";
          hyprlandLayoutRadiusOverride = -1;
          firstDayOfWeek = 0;
          showWeekNumber = true;
          windSpeedUnit = "kmh";
          density = "dense";
          interfaceStyle = "expressive";
          barElevationEnabled = false;
          blurredWallpaperLayer = false;
          blurWallpaperOnOverview = false;
          controlCenterIconScale = 1;
          controlCenterWidgets = [
            {
              col = 0;
              enabled = true;
              h = 1;
              id = "user";
              row = 0;
              small = false;
              w = 6;
            }
            {
              col = 6;
              enabled = true;
              h = 1;
              id = "edit";
              row = 0;
              small = false;
              w = 1;
            }
            {
              col = 7;
              enabled = true;
              h = 1;
              id = "settings";
              row = 0;
              small = false;
              w = 1;
            }
            {
              col = 0;
              enabled = true;
              h = 1;
              id = "volumeSlider";
              row = 1;
              small = true;
              w = 4;
            }
            {
              col = 4;
              enabled = true;
              h = 1;
              id = "brightnessSlider";
              row = 1;
              small = true;
              w = 4;
            }
            {
              col = 0;
              enabled = true;
              h = 1;
              id = "wifi";
              row = 2;
              small = true;
              w = 4;
            }
            {
              col = 4;
              enabled = true;
              h = 1;
              id = "bluetooth";
              row = 2;
              small = true;
              w = 4;
            }
            {
              col = 0;
              enabled = true;
              h = 1;
              id = "audioInput";
              row = 3;
              small = true;
              w = 4;
            }
            {
              col = 4;
              enabled = true;
              h = 1;
              id = "audioOutput";
              row = 3;
              small = true;
              w = 4;
            }
            {
              col = 0;
              enabled = true;
              h = 1;
              id = "doNotDisturb";
              row = 4;
              small = true;
              w = 4;
            }
            {
              col = 4;
              enabled = true;
              h = 1;
              id = "idleInhibitor";
              row = 4;
              small = true;
              w = 4;
            }
            {
              col = 0;
              enabled = true;
              h = 1;
              id = "builtin_vpn";
              row = 5;
              small = true;
              w = 4;
            }
            {
              col = 4;
              enabled = true;
              h = 1;
              id = "plugin_dankKDEConnect";
              row = 5;
              small = true;
              w = 4;
            }
            {
              col = 0;
              enabled = true;
              h = 1;
              id = "runningApps";
              row = 6;
              small = true;
              w = 16;
            }
          ];
          scrollTitleEnabled = true;
          audioVisualizerEnabled = true;
          centeringMode = "index";
          sortAppsAlphabetically = false;
          appLauncherGridColumns = 4;
          niriOverviewOverlayEnabled = true;
          dankLauncherV2Size = "compact";
          dankLauncherV2BorderEnabled = false;
          dankLauncherV2BorderThickness = 2;
          dankLauncherV2BorderColor = "primary";
          dankLauncherV2ShowFooter = true;
          dashOptions = {
            media = {
              animatedArt = true;
            };
          };
          iconThemeDark = "Papirus";
          cursorSettings = {
            dwl = {
              cursorHideTimeout = 0;
            };
            hyprland = {
              hideOnKeyPress = true;
              hideOnTouch = false;
              inactiveTimeout = 0;
            };
            niri = {
              hideAfterInactiveMs = 0;
              hideWhenTyping = false;
            };
            size = 24;
            theme = "System Default";
          };
          notepadUseMonospace = true;
          notepadFontSize = 14;
          notepadShowLineNumbers = false;
          notepadTransparencyOverride = -1;
          notepadLastCustomTransparency = 0.7;
          soundsEnabled = true;
          useSystemSoundTheme = false;
          soundNewNotification = true;
          soundVolumeChanged = true;
          soundPluggedIn = true;
          acMonitorTimeout = 600;
          acLockTimeout = 180;
          acSuspendTimeout = 1800;
          acSuspendBehavior = 0;
          acProfileName = "2";
          batteryMonitorTimeout = 600;
          batteryLockTimeout = 180;
          batterySuspendTimeout = 1200;
          batterySuspendBehavior = 0;
          batteryProfileName = "0";
          batteryChargeLimit = 100;
          lockBeforeSuspend = true;
          loginctlLockIntegration = true;
          fadeToLockEnabled = true;
          fadeToLockGracePeriod = 5;
          fadeToDpmsEnabled = true;
          fadeToDpmsGracePeriod = 5;
          launchPrefix = "uwsm app -- ";
          syncModeWithPortal = true;
          terminalsAlwaysDark = false;
          muxType = "herdr";
          runDmsMatugenTemplates = true;
          matugenTemplateGtk = true;
          matugenTemplateNiri = false;
          matugenTemplateHyprland = false;
          matugenTemplateMangowc = false;
          matugenTemplateQt5ct = true;
          matugenTemplateQt6ct = true;
          matugenTemplateFirefox = false;
          matugenTemplatePywalfox = false;
          matugenTemplateZenBrowser = false;
          matugenTemplateVesktop = false;
          matugenTemplateEquibop = false;
          matugenTemplateGhostty = false;
          matugenTemplateKitty = false;
          matugenTemplateFoot = false;
          matugenTemplateAlacritty = false;
          matugenTemplateNeovim = false;
          matugenTemplateWezterm = false;
          matugenTemplateDgop = true;
          matugenTemplateKcolorscheme = true;
          matugenTemplateVscode = false;
          matugenTemplateEmacs = false;
          notificationOverlayEnabled = true;
          modalDarkenBackground = true;
          lockScreenPowerOffMonitorsOnLock = false;
          enableFprint = true;
          maxFprintTries = 3;
          enableU2f = true;
          u2fMode = "or";
          lockScreenInactiveColor = "#000000";
          lockScreenVideoEnabled = true;
          lockScreenVideoPath = "/home/augusto/media/animated/";
          lockScreenVideoCycling = true;
          notificationTimeoutLow = 5000;
          notificationTimeoutNormal = 5000;
          notificationTimeoutCritical = 0;
          notificationCompactMode = true;
          notificationPopupPosition = 0;
          notificationHistoryEnabled = true;
          notificationHistoryMaxCount = 50;
          notificationHistoryMaxAgeDays = 7;
          notificationHistorySaveLow = true;
          notificationHistorySaveNormal = true;
          notificationHistorySaveCritical = true;
          notificationFocusedMonitor = true;
          osdAlwaysShowValue = false;
          osdPosition = 5;
          osdVolumeEnabled = true;
          osdMediaVolumeEnabled = true;
          osdBrightnessEnabled = true;
          osdIdleInhibitorEnabled = true;
          osdMicMuteEnabled = true;
          osdCapsLockEnabled = true;
          osdPowerProfileEnabled = true;
          osdAudioOutputEnabled = true;
          updaterUseCustomCommand = false;
          screenPreferences = {
            wallpaper = [
              "all"
            ];
          };
          barConfigs = [
            {
              autoHide = false;
              autoHideDelay = 250;
              borderColor = "surfaceText";
              borderEnabled = false;
              borderOpacity = 1;
              borderThickness = 1;
              bottomGap = 0;
              centerWidgets = [
                "weather"
                {
                  audioScrollMode = "nothing";
                  enabled = true;
                  id = "music";
                  mediaSize = 3;
                }
                {
                  clockCompactMode = false;
                  enabled = true;
                  id = "clock";
                }
                {
                  enabled = true;
                  id = "dcalUpcoming";
                }
              ];
              enabled = true;
              followInterfaceStyle = false;
              fontScale = 1;
              gothCornerRadiusOverride = true;
              gothCornerRadiusValue = 12;
              gothCornersEnabled = true;
              id = "default";
              innerPadding = -8;
              leftWidgets = [
                {
                  enabled = true;
                  id = "launcherButton";
                  launcherLogoBrightness = 0.5;
                  launcherLogoColorOverride = "primary";
                  launcherLogoContrast = 1;
                  launcherLogoMode = "os";
                  launcherLogoSizeOffset = 0;
                }
                {
                  enabled = true;
                  groupWorkspaceApps = true;
                  id = "workspaceSwitcher";
                  maxWorkspaceIcons = 5;
                  reverseScrolling = false;
                  showOccupiedWorkspacesOnly = false;
                  showWorkspaceApps = false;
                  showWorkspaceIndex = true;
                  showWorkspaceName = false;
                  showWorkspacePadding = true;
                  workspaceColorMode = "default";
                  workspaceFocusedBorderColor = "primary";
                  workspaceFocusedBorderEnabled = false;
                  workspaceFocusedBorderThickness = 2;
                  workspaceFollowFocus = false;
                  workspaceOccupiedColorMode = "none";
                  workspaceUnfocusedColorMode = "default";
                  workspaceUrgentColorMode = "default";
                }
                {
                  enabled = true;
                  focusedWindowCompactMode = false;
                  id = "focusedWindow";
                }
                {
                  enabled = true;
                  id = "runningApps";
                  runningAppsCompactMode = true;
                  runningAppsCurrentWorkspace = true;
                  runningAppsGroupByApp = false;
                }
                {
                  enabled = true;
                  id = "dankbarPinentry";
                }
              ];
              name = "Main Bar";
              noBackground = false;
              openOnOverview = false;
              popupGapsAuto = true;
              popupGapsManual = 4;
              position = 0;
              rightWidgets = [
                {
                  enabled = true;
                  id = "systemTray";
                }
                {
                  enabled = true;
                  id = "separator";
                }
                {
                  enabled = true;
                  id = "notificationButton";
                }
                {
                  enabled = true;
                  id = "clipboard";
                }
                {
                  enabled = true;
                  id = "developerUtilities";
                }
                {
                  enabled = true;
                  id = "cpuUsage";
                }
                {
                  enabled = true;
                  id = "memUsage";
                }
                {
                  enabled = true;
                  id = "battery";
                }
                {
                  enabled = true;
                  id = "controlCenterButton";
                  showAudioIcon = true;
                  showAudioPercent = true;
                  showBatteryIcon = false;
                  showBluetoothIcon = true;
                  showBrightnessIcon = false;
                  showBrightnessPercent = false;
                  showMicIcon = false;
                  showMicPercent = false;
                  showNetworkIcon = true;
                  showPrinterIcon = true;
                  showScreenSharingIcon = true;
                  showVpnIcon = true;
                }
                {
                  enabled = true;
                  id = "powerMenuButton";
                }
              ];
              screenPreferences = [
                "all"
              ];
              showOnLastDisplay = true;
              spacing = 0;
              squareCorners = true;
              transparency = 0.3;
              visible = true;
              widgetFollowInterfaceStyle = false;
              widgetTransparency = 0.8;
              widgetPadding = 5;
            }
          ];
          clipboardEnterToPaste = true;
        };

        session = {
          wallpaperPath = "${config.home.homeDirectory}/media/wallpapers/807509.jpg";
          wallpaperCyclingEnabled = true;
          wallpaperCyclingMode = "interval";
          wallpaperCyclingInterval = 300;
          wallpaperTransition = "random";
        };

        clipboardSettings = {
          maxHistory = 100;
          maxPinned = 50;
          clearAtStartup = false;
        };

        plugins = {
          dankbarPinentry = {
            enable = true;
            settings = {
              placement = "bar";
              barText = false;
              focusMode = "take";
              autoOpen = false;
              notify = true;
              notifyIcon = "dialog-password";
              showOwner = true;
              timeoutRing = true;
            };
          };

          commandRunner.enable = true;
          calculator.enable = true;

          worldClock = {
            enable = false;
            settings.timezones = [
              {
                timezone = "America/Sao_Paulo";
                label = "🇧🇷";
              }
              {
                timezone = "Europe/Berlin";
                label = "🇩🇪";
              }
            ];
          };

          webSearch = {
            enable = true;
            settings.defaultEngine = "duckduckgo";
          };

          emojiLauncher = {
            enable = true;
            settings = {
              noTrigger = false;
              trigger = ":";
            };
          };

          displaySettings.enable = true;
          dankHyprlandWindows.enable = true;
          developerUtilities.enable = true;

          dankKDEConnect.enable = true;
          wallpaperCarousel.enable = true;

          screenCaptureToolbar = {
            enable = true;
            settings = {
              multiMonitorScreenshot = true;
              videoFormat = "mp4";
              recordAudio = false;
              customPath = "${config.home.homeDirectory}/pictures/screenshots";
              videoCustomPath = "${config.home.homeDirectory}/videos/recordings";
              saveToDisk = false;
            };
          };

          dcalUpcoming = {
            enable = true;
            settings = {
              refreshInterval = 300;
              calendarIds = [
                # this list has to be updated on a new system
                "f98a6a1a-3d56-4d95-984f-7729848ec462" # Work
                "41dfaaff-d579-4479-8f01-2d8155ae4f30" # Personal G
                "52bdfe8c-9aa2-48a7-92a2-9c20028e60c9" # Personal A
              ];
            };
          };
        };
      };

      programs.dank-calendar = {
        enable = true;
        systemd.enable = true;

        settings = {
          firstDayOfWeek = 0;
          timeFormat = "24h";
          use24HourClock = true;
          showWeekNumbers = true;
        };
      };

      home.packages = [
        pkgs.libnotify
        pkgs.inotify-tools
        pkgs.slurp
        pkgs.grim
        pkgs.satty
      ];
    };
  };
}

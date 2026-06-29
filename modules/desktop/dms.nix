{
  den,
  inputs,
  lib,
  ...
}: {
  flake-file.inputs.dms = {
    url = lib.mkDefault "github:AvengeMedia/DankMaterialShell";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  flake-file.inputs.dms-plugins = {
    url = lib.mkDefault "github:AvengeMedia/dms-plugin-registry";
    inputs.nixpkgs.follows = "nixpkgs";
  };
  flake-file.inputs.dankcalendar = {
    url = lib.mkDefault "github:AvengeMedia/dankcalendar";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.dms = {
    nixos = {
      pkgs,
      config,
      ...
    }: {
      imports = lib.optionals (inputs ? dms) [inputs.dms.nixosModules.greeter];

      qt.enable = true;
      programs.kdeconnect.enable = true;

      users.users.augusto.extraGroups = ["greeter"];

      programs.dank-material-shell.greeter = {
        enable = true;
        compositor.name = "hyprland";
        compositor.customConfig = ''
          env = XCURSOR_SIZE,24
          env = XCURSOR_THEME,catppuccin-mocha-blue-cursors
          exec-once = hyprctl setcursor catppuccin-mocha-blue-cursors 24
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
        ++ lib.optionals (inputs ? dankcalendar) [inputs.dankcalendar.homeModules.default];

      xsession.preferStatusNotifierItems = true;

      # Inject sops-decrypted API keys into the DMS systemd service
      systemd.user.services.dms.Service = {
        EnvironmentFile = ["%t/dms-env"];
      };

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
          currentThemeName = "custom";
          currentThemeCategory = "registry";
          customThemeFile = "/home/augusto/.config/DankMaterialShell/themes/catppuccin/theme.json";
          registryThemeVariants = {
            catppuccin = {
              flavor = "mocha";
              accent = "blue";
            };
          };
          matugenScheme = "scheme-tonal-spot";
          runUserMatugenTemplates = true;
          cornerRadius = 6;
          popupTransparency = 1;
          dockTransparency = 1;
          widgetBackgroundColor = "s";
          widgetColorMode = "default";

          fontFamily = "Inter Variable";
          monoFontFamily = "MonaspiceRn Nerd Font Mono";
          fontWeight = 400;
          fontScale = 1;

          firstDayOfWeek = 0;
          showWeekNumber = true;
          use24HourClock = true;
          showSeconds = false;
          useFahrenheit = false;
          windSpeedUnit = "kmh";

          animationSpeed = 1;
          customAnimationDuration = 500;

          wallpaperFillMode = "Fill";
          blurredWallpaperLayer = false;
          blurWallpaperOnOverview = false;

          showLauncherButton = true;
          showWorkspaceSwitcher = true;
          showFocusedWindow = true;
          showWeather = true;
          showMusic = true;
          showClipboard = true;
          clipboardEnterToPaste = true;
          showCpuUsage = true;
          showMemUsage = true;
          showCpuTemp = true;
          showGpuTemp = true;
          selectedGpuIndex = 0;
          showSystemTray = true;
          showClock = true;
          showNotificationButton = true;
          showBattery = true;
          showControlCenterButton = true;
          showCapsLockIndicator = true;
          showPrivacyButton = true;

          controlCenterShowNetworkIcon = true;
          controlCenterShowBluetoothIcon = true;
          controlCenterShowAudioIcon = true;
          controlCenterShowAudioPercent = false;
          controlCenterShowVpnIcon = true;
          controlCenterShowBrightnessIcon = false;
          controlCenterShowBrightnessPercent = false;
          controlCenterShowMicIcon = false;
          controlCenterShowMicPercent = false;
          controlCenterShowBatteryIcon = false;
          controlCenterShowPrinterIcon = false;
          controlCenterShowScreenSharingIcon = true;

          privacyShowMicIcon = true;
          privacyShowCameraIcon = true;
          privacyShowScreenShareIcon = true;

          controlCenterWidgets = [
            {
              id = "volumeSlider";
              enabled = true;
              width = 50;
            }
            {
              id = "brightnessSlider";
              enabled = true;
              width = 50;
            }
            {
              id = "wifi";
              enabled = true;
              width = 50;
            }
            {
              id = "bluetooth";
              enabled = true;
              width = 50;
            }
            {
              id = "audioInput";
              enabled = true;
              width = 50;
            }
            {
              id = "audioOutput";
              enabled = true;
              width = 50;
            }
            {
              id = "doNotDisturb";
              enabled = true;
              width = 50;
            }
            {
              id = "idleInhibitor";
              enabled = true;
              width = 50;
            }
            {
              id = "builtin_vpn";
              enabled = true;
              width = 50;
            }
            {
              id = "plugin_dankKDEConnect";
              enabled = true;
              width = 50;
            }
          ];

          showWorkspaceIndex = true;
          showWorkspaceName = false;
          showWorkspacePadding = true;
          workspaceScrolling = false;
          showWorkspaceApps = false;
          maxWorkspaceIcons = 5;
          groupWorkspaceApps = true;
          workspaceFollowFocus = false;
          showOccupiedWorkspacesOnly = false;
          reverseScrolling = false;
          workspaceColorMode = "default";
          workspaceOccupiedColorMode = "none";
          workspaceUnfocusedColorMode = "default";
          workspaceUrgentColorMode = "default";
          workspaceFocusedBorderEnabled = false;
          workspaceFocusedBorderColor = "primary";
          workspaceFocusedBorderThickness = 2;

          waveProgressEnabled = true;
          scrollTitleEnabled = true;
          audioVisualizerEnabled = true;
          audioScrollMode = "volume";
          mediaSize = 1;

          clockCompactMode = false;
          focusedWindowCompactMode = false;
          runningAppsCompactMode = true;
          keyboardLayoutNameCompactMode = false;
          runningAppsCurrentWorkspace = true;
          runningAppsGroupByApp = false;

          centeringMode = "index";
          appLauncherViewMode = "list";
          launchPrefix = "uwsm app -- ";
          spotlightModalViewMode = "list";
          sortAppsAlphabetically = false;
          appLauncherGridColumns = 4;
          spotlightCloseNiriOverview = true;
          niriOverviewOverlayEnabled = true;
          dankLauncherV2Size = "compact";
          dankLauncherV2BorderEnabled = false;
          dankLauncherV2BorderThickness = 2;
          dankLauncherV2BorderColor = "primary";
          dankLauncherV2ShowFooter = true;

          useAutoLocation = true;
          weatherEnabled = true;

          networkPreference = "wifi";
          iconTheme = "Papirus";

          cursorSettings = {
            theme = "System Default";
            size = 24;
            niri = {
              hideWhenTyping = false;
              hideAfterInactiveMs = 0;
            };
            hyprland = {
              hideOnKeyPress = true;
              hideOnTouch = false;
              inactiveTimeout = 0;
            };
            dwl.cursorHideTimeout = 0;
          };

          launcherLogoMode = "os";
          launcherLogoColorOverride = "primary";
          launcherLogoColorInvertOnMode = false;
          launcherLogoBrightness = 0.5;
          launcherLogoContrast = 1;
          launcherLogoSizeOffset = 0;

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
          lockScreenShowPowerActions = true;
          lockScreenShowSystemIcons = true;
          lockScreenShowTime = true;
          lockScreenShowDate = true;
          lockScreenShowProfileImage = true;
          lockScreenShowPasswordField = true;
          lockScreenPowerOffMonitorsOnLock = false;
          lockScreenVideoEnabled = true;
          lockScreenVideoPath = "/home/augusto/media/animated/";
          lockScreenVideoCycling = true;
          enableFprint = true;
          maxFprintTries = 3;
          enableU2f = true;
          u2fMode = "or";
          lockScreenActiveMonitor = "all";
          lockScreenInactiveColor = "#000000";
          lockScreenNotificationMode = 0;

          gtkThemingEnabled = true;
          qtThemingEnabled = true;
          syncModeWithPortal = true;
          terminalsAlwaysDark = false;
          muxType = "zellij";
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

          showDock = false;
          dockAutoHide = false;
          dockSmartAutoHide = false;
          dockGroupByApp = false;
          dockOpenOnOverview = false;
          dockPosition = 1;
          dockSpacing = 4;
          dockBottomGap = 0;
          dockMargin = 0;
          dockIconSize = 40;
          dockIndicatorStyle = "circle";
          dockBorderEnabled = false;
          dockBorderColor = "surfaceText";
          dockBorderOpacity = 1;
          dockBorderThickness = 1;
          dockIsolateDisplays = false;
          dockLauncherEnabled = false;
          dockLauncherLogoMode = "apps";
          dockLauncherLogoSizeOffset = 0;
          dockLauncherLogoBrightness = 0.5;
          dockLauncherLogoContrast = 1;

          notificationOverlayEnabled = true;
          modalDarkenBackground = true;
          hideBrightnessSlider = false;
          notificationTimeoutLow = 5000;
          notificationTimeoutNormal = 5000;
          notificationTimeoutCritical = 0;
          notificationCompactMode = true;
          notificationPopupPosition = 0;
          notificationFocusedMonitor = true;
          notificationHistoryEnabled = true;
          notificationHistoryMaxCount = 50;
          notificationHistoryMaxAgeDays = 7;
          notificationHistorySaveLow = true;
          notificationHistorySaveNormal = true;
          notificationHistorySaveCritical = true;

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

          powerActionConfirm = true;
          powerActionHoldDuration = 0.5;
          powerMenuActions = ["reboot" "logout" "poweroff" "lock" "suspend" "restart"];
          powerMenuDefaultAction = "logout";
          powerMenuGridLayout = false;

          updaterHideWidget = true;
          updaterUseCustomCommand = false;

          displayNameMode = "system";
          screenPreferences.wallpaper = ["all"];

          barConfigs = [
            {
              id = "default";
              name = "Main Bar";
              enabled = true;
              position = 0;
              screenPreferences = ["all"];
              showOnLastDisplay = true;
              leftWidgets = [
                "launcherButton"
                "workspaceSwitcher"
                "focusedWindow"
                {
                  id = "runningApps";
                  enabled = true;
                }
              ];
              centerWidgets = [
                "weather"
                "music"
                {
                  id = "clock";
                  enabled = true;
                  clockCompactMode = false;
                }
                {
                  id = "dcalUpcoming";
                  enabled = true;
                }
              ];
              rightWidgets = [
                {
                  id = "systemTray";
                  enabled = true;
                }
                {
                  id = "separator";
                  enabled = true;
                }
                {
                  id = "notificationButton";
                  enabled = true;
                }
                {
                  id = "clipboard";
                  enabled = true;
                }
                {
                  id = "developerUtilities";
                  enabled = true;
                }
                {
                  id = "cpuUsage";
                  enabled = true;
                }
                {
                  id = "memUsage";
                  enabled = true;
                }
                {
                  id = "battery";
                  enabled = true;
                }
                {
                  id = "controlCenterButton";
                  enabled = true;
                  showAudioPercent = true;
                  showBrightnessIcon = false;
                  showBrightnessPercent = false;
                  showMicIcon = false;
                  showBatteryIcon = false;
                  showPrinterIcon = true;
                }
                {
                  id = "sessionPower";
                  enabled = true;
                }
              ];
              spacing = 0;
              innerPadding = -8;
              bottomGap = 0;
              transparency = 0.3;
              widgetTransparency = 0.80;
              squareCorners = true;
              noBackground = false;
              gothCornersEnabled = true;
              gothCornerRadiusOverride = false;
              gothCornerRadiusValue = 12;
              borderEnabled = false;
              borderColor = "surfaceText";
              borderOpacity = 1;
              borderThickness = 1;
              fontScale = 1;
              autoHide = false;
              autoHideDelay = 250;
              openOnOverview = false;
              visible = true;
              popupGapsAuto = true;
              popupGapsManual = 4;
            }
          ];

          desktopClockEnabled = false;
          desktopClockStyle = "analog";
          desktopClockTransparency = 0.8;
          desktopClockColorMode = "primary";
          desktopClockShowDate = true;
          desktopClockShowAnalogNumbers = false;
          desktopClockShowAnalogSeconds = true;
          desktopClockX = -1;
          desktopClockY = -1;
          desktopClockWidth = 280;
          desktopClockHeight = 180;
          desktopClockDisplayPreferences = ["all"];

          systemMonitorEnabled = false;
          systemMonitorShowHeader = true;
          systemMonitorTransparency = 0.8;
          systemMonitorColorMode = "primary";
          systemMonitorShowCpu = true;
          systemMonitorShowCpuGraph = true;
          systemMonitorShowCpuTemp = true;
          systemMonitorShowGpuTemp = false;
          systemMonitorShowMemory = true;
          systemMonitorShowMemoryGraph = true;
          systemMonitorShowNetwork = true;
          systemMonitorShowNetworkGraph = true;
          systemMonitorShowDisk = true;
          systemMonitorShowTopProcesses = false;
          systemMonitorTopProcessCount = 3;
          systemMonitorTopProcessSortBy = "cpu";
          systemMonitorGraphInterval = 60;
          systemMonitorLayoutMode = "auto";
          systemMonitorX = -1;
          systemMonitorY = -1;
          systemMonitorWidth = 320;
          systemMonitorHeight = 480;
          systemMonitorDisplayPreferences = ["all"];

          greeterEnableFprint = true;
          greeterEnableU2f = true;

          desktopWidgetInstances = [
            {
              id = "dw_1769172254836_7kkr5ii2j";
              widgetType = "systemMonitor";
              name = "System Monitor";
              enabled = true;
              config = {
                showHeader = true;
                transparency = 0.3;
                colorMode = "primary";
                customColor = "#ffffff";
                showCpu = true;
                showCpuGraph = true;
                showCpuTemp = true;
                showGpuTemp = false;
                showMemory = true;
                showMemoryGraph = true;
                showNetwork = true;
                showNetworkGraph = true;
                showDisk = true;
                showTopProcesses = true;
                topProcessCount = 3;
                topProcessSortBy = "cpu";
                layoutMode = "auto";
                graphInterval = 60;
                displayPreferences = ["all"];
                clickThrough = true;
                syncPositionAcrossScreens = false;
              };
              positions = {
                "eDP-1" = {
                  x = 10;
                  y = 32;
                  width = 320;
                  height = 480;
                };
                "DP-1" = {
                  x = 10;
                  y = 32;
                  width = 320;
                  height = 480;
                };
                "DP-2" = {
                  x = 10;
                  y = 32;
                  width = 320;
                  height = 480;
                };
                "DP-3" = {
                  x = 10;
                  y = 32;
                  width = 320;
                  height = 480;
                };
              };
            }
            {
              id = "dw_1769172259317_m4cnowlqm";
              widgetType = "dankDesktopWeather";
              name = "Weather";
              enabled = true;
              config = {
                displayPreferences = ["all"];
                showOnOverlay = false;
                clickThrough = true;
                syncPositionAcrossScreens = false;
                viewMode = "forecast";
                backgroundOpacity = 30;
              };
              positions = {
                "eDP-1" = {
                  x = 340;
                  y = 32;
                  width = 320;
                  height = 480;
                };
                "DP-1" = {
                  x = 340;
                  y = 32;
                  width = 320;
                  height = 480;
                };
                "DP-2" = {
                  x = 340;
                  y = 32;
                  width = 320;
                  height = 480;
                };
                "DP-3" = {
                  x = 340;
                  y = 32;
                  width = 320;
                  height = 480;
                };
              };
            }
          ];

          configVersion = 5;
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
          commandRunner.enable = true;
          dankBatteryAlerts.enable = true;
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

          sessionPower.enable = true;

          emojiLauncher = {
            enable = true;
            settings = {
              noTrigger = false;
              trigger = ":";
            };
          };

          displaySettings.enable = true;
          dankDesktopWeather.enable = true;
          dankHyprlandWindows.enable = true;
          developerUtilities.enable = true;

          aiAssistant = {
            enable = true;
            settings = {
              provider = "anthropic";
              model = "claude-opus-4-6";
              apiKeyEnvVar = "ANTHROPIC_API_KEY";
            };
          };

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

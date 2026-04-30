{
  den,
  inputs,
  lib,
  ...
}: {
  den.aspects.macmini = {
    includes = with den.aspects; [
      yabai-skhd
    ];

    darwin = {pkgs, ...}: {
      imports = lib.optionals (inputs ? nix-homebrew) [
        inputs.nix-homebrew.darwinModules.nix-homebrew
      ];

      networking.computerName = "macmini";

      time.timeZone = "Europe/Berlin";

      # Touch ID for sudo
      security.pam.services.sudo_local.touchIdAuth = true;

      system.primaryUser = "augusto";

      system.defaults = {
        NSGlobalDomain = {
          AppleInterfaceStyle = "Dark";
          AppleShowAllExtensions = true;
          AppleShowAllFiles = true;
          ApplePressAndHoldEnabled = false; # disable accent popup, allow key repeat
          InitialKeyRepeat = 15;
          KeyRepeat = 2;
          NSAutomaticCapitalizationEnabled = false;
          NSAutomaticDashSubstitutionEnabled = false;
          NSAutomaticPeriodSubstitutionEnabled = false;
          NSAutomaticQuoteSubstitutionEnabled = false;
          NSAutomaticSpellingCorrectionEnabled = false;
          NSDocumentSaveNewDocumentsToCloud = false;
          NSNavPanelExpandedStateForSaveMode = true;
          NSNavPanelExpandedStateForSaveMode2 = true;
          # Enable full keyboard access (Tab traverses everything, not just text inputs)
          AppleKeyboardUIMode = 3;
          # Faster window/menu animations
          NSWindowResizeTime = 0.001;
          NSAutomaticWindowAnimationsEnabled = false;
          # Trackpad/mouse: tap to click
          "com.apple.mouse.tapBehavior" = 1;
          "com.apple.swipescrolldirection" = true;
        };

        dock = {
          autohide = true;
          autohide-delay = 0.0;
          autohide-time-modifier = 0.2;
          mru-spaces = false;
          show-recents = false;
          tilesize = 48;
          orientation = "bottom";
          wvous-tl-corner = 1;
          wvous-tr-corner = 1;
          wvous-bl-corner = 1;
          wvous-br-corner = 1;
        };

        finder = {
          AppleShowAllExtensions = true;
          AppleShowAllFiles = true;
          FXEnableExtensionChangeWarning = false;
          ShowPathbar = true;
          ShowStatusBar = true;
          _FXShowPosixPathInTitle = true;
          _FXSortFoldersFirst = true;
          FXDefaultSearchScope = "SCcf"; # search current folder by default
          FXPreferredViewStyle = "Nlsv"; # list view
        };

        loginwindow = {
          GuestEnabled = false;
          DisableConsoleAccess = true;
        };

        screencapture = {
          location = "~/pictures/screenshots";
          type = "png";
        };

        trackpad = {
          Clicking = true;
          TrackpadRightClick = true;
          TrackpadThreeFingerDrag = true;
        };

        #   64 = "Show Spotlight search"
        #   65 = "Show Finder search window"
        CustomUserPreferences = {
          "com.apple.symbolichotkeys" = {
            AppleSymbolicHotKeys = {
              "64".enabled = false;
              "65".enabled = false;
            };
          };
        };
      };

      # Apple keyboard
      system.keyboard = {
        enableKeyMapping = true;
        remapCapsLockToControl = true;
      };

      nix-homebrew = lib.mkIf (inputs ? nix-homebrew) {
        enable = true;
        enableRosetta = false;
        user = "augusto";
        # Auto-update brew when nix-homebrew runs
        autoMigrate = true;
      };

      homebrew = {
        enable = true;

        onActivation = {
          autoUpdate = true;
          upgrade = true;
          # Uninstall anything not declared here
          cleanup = "zap";
        };

        taps = [];
        brews = [];

        casks = [
          "fusion360"
          "vlc"
          "blender"
        ];

        masApps = {};
      };

      programs.fish.enable = true;

      environment.shells = with pkgs; [bashInteractive fish];
    };
  };
}

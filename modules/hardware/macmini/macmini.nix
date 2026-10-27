{
  den,
  inputs,
  lib,
  ...
}: {
  flake-file.inputs.eurkey-next = {
    url = lib.mkDefault "github:felixfoertsch/EurKEY-Next/2026.03.22";
    flake = false;
  };

  den.aspects.macmini = {
    includes = with den.aspects; [
      ollama
      wyoming
      honcho
      hermes-agent
      open-webui
      laya
      libretranslate
    ];

    darwin = {pkgs, ...}: let
      eurkey-next-bundle = pkgs.stdenvNoCC.mkDerivation {
        pname = "eurkey-next-bundle";
        version = "2026.03.22";
        src = inputs.eurkey-next;
        nativeBuildInputs = [pkgs.bash pkgs.python3];
        dontConfigure = true;
        dontFixup = true;
        buildPhase = ''
          runHook preBuild
          patchShebangs scripts/build-bundle.sh
          bash scripts/build-bundle.sh --version "$version"
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          mkdir -p $out
          cp -R build/EurKEY-Next.bundle $out/
          runHook postInstall
        '';
      };
    in {
      imports = lib.optionals (inputs ? nix-homebrew) [
        inputs.nix-homebrew.darwinModules.nix-homebrew
      ];

      networking.computerName = "macmini";

      time.timeZone = "Europe/Berlin";

      services.openssh.enable = true;

      # YubiKey-backed key (cardno:15_851_450), same one the raspi accepts.
      # nix-darwin renders this to /etc/ssh/nix_authorized_keys.d/augusto and
      # wires sshd's AuthorizedKeysCommand at it.
      users.users.augusto.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE8G/L1OaaDxw1pFQ8vYKVBSMnPZbty8AiUECQaHwNmW"
      ];

      power = {
        sleep.computer = "never";
        restartAfterPowerFailure = true;
      };

      # Touch ID for sudo
      security.pam.services.sudo_local.touchIdAuth = true;

      system.primaryUser = "augusto";

      programs._1password-gui.enable = true;

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
          AppleFontSmoothing = 2;
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

          "com.apple.HIToolbox" = {
            AppleEnabledInputSources = [
              {
                InputSourceKind = "Keyboard Layout";
                "KeyboardLayout ID" = -1;
                "KeyboardLayout Name" = "EurKEY Next";
              }
              {
                "Bundle ID" = "com.apple.PressAndHold";
                InputSourceKind = "Non Keyboard Input Method";
              }
              {
                "Bundle ID" = "com.apple.CharacterPaletteIM";
                InputSourceKind = "Non Keyboard Input Method";
              }
            ];
            AppleSelectedInputSources = [
              {
                InputSourceKind = "Keyboard Layout";
                "KeyboardLayout ID" = -1;
                "KeyboardLayout Name" = "EurKEY Next";
              }
              {
                "Bundle ID" = "com.apple.PressAndHold";
                InputSourceKind = "Non Keyboard Input Method";
              }
            ];
          };
        };
      };

      # Apple keyboard
      system.keyboard = {
        enableKeyMapping = true;
        remapCapsLockToControl = true;
      };

      system.activationScripts.postActivation.text = ''
        echo "Installing EurKEY-Next keyboard layout bundle..."
        rm -rf "/Library/Keyboard Layouts/EurKEY-Next.bundle"
        cp -R "${eurkey-next-bundle}/EurKEY-Next.bundle" "/Library/Keyboard Layouts/EurKEY-Next.bundle"
        chmod -R u+w,go+rX "/Library/Keyboard Layouts/EurKEY-Next.bundle"
      '';

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
          "autodesk-fusion"
          "vlc"
          "blender"
          "orcaslicer"
          "snapmaker-orca"
          "mos"
          "freecad"
        ];

        masApps = {};
      };

      programs.fish.enable = true;

      environment.shells = with pkgs; [bashInteractive fish];
    };
  };
}

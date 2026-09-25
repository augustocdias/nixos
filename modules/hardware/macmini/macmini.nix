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
      open-webui
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

      ollamaHome = "/var/lib/ollama";
      ollamaPort = 11434;

      ollamaModels = [
        "gpt-oss:20b"
      ];

      voiceDaemon = name: {
        command,
        environment ? {},
        keepAlive ? true,
        home ? null,
      }: {
        inherit command;
        environment = lib.optionalAttrs (home != null) {HOME = home;} // environment;
        serviceConfig = {
          KeepAlive = keepAlive;
          RunAtLoad = true;
          StandardOutPath = "/var/log/${name}.log";
          StandardErrorPath = "/var/log/${name}.log";
        };
      };

      # launchd has no ordering, so poll the server instead of racing it.
      ollamaModelLoader = pkgs.writeShellScript "ollama-model-loader" ''
        set -u
        until ${lib.getExe pkgs.curl} -fsS --max-time 5 \
          "http://127.0.0.1:${toString ollamaPort}/api/version" >/dev/null; do
          echo "waiting for ollama on port ${toString ollamaPort}..."
          sleep 2
        done

        status=0
        ${lib.concatMapStringsSep "\n" (model: ''
            echo "pulling ${model}"
            ${lib.getExe pkgs.ollama} pull ${lib.escapeShellArg model} || status=1
          '')
          ollamaModels}
        exit "$status"
      '';
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

        mkdir -p ${ollamaHome}/models
        mkdir -p /var/lib/wyoming/faster-whisper
        mkdir -p /var/lib/wyoming/piper
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

      launchd.daemons = {
        ollama = voiceDaemon "ollama" {
          command = "${lib.getExe pkgs.ollama} serve";
          home = ollamaHome;
          environment = {
            OLLAMA_HOST = "[::]:${toString ollamaPort}";
            OLLAMA_MODELS = "${ollamaHome}/models";
            OLLAMA_CONTEXT_LENGTH = "16384";
            OLLAMA_KEEP_ALIVE = "5m";
            OLLAMA_NUM_PARALLEL = "1";
            OLLAMA_FLASH_ATTENTION = "1";
            OLLAMA_NO_CLOUD = "1";
          };
        };

        ollama-model-loader = voiceDaemon "ollama-model-loader" {
          command = "${ollamaModelLoader}";
          home = ollamaHome;
          environment = {
            OLLAMA_HOST = "127.0.0.1:${toString ollamaPort}";
            OLLAMA_MODELS = "${ollamaHome}/models";
          };
          # One-shot: retry on failure, don't respawn after a clean pull.
          keepAlive = {SuccessfulExit = false;};
        };

        wyoming-faster-whisper = voiceDaemon "wyoming-faster-whisper" {
          command = lib.concatStringsSep " " [
            (lib.getExe pkgs.wyoming-faster-whisper)
            "--data-dir /var/lib/wyoming/faster-whisper"
            "--uri tcp://0.0.0.0:10300"
            "--model small-int8"
            "--language auto"
          ];
          # https://github.com/rhasspy/wyoming-faster-whisper/issues/27
          environment.HF_HOME = "/tmp";
        };

        wyoming-piper = voiceDaemon "wyoming-piper" {
          command = lib.concatStringsSep " " [
            (lib.getExe pkgs.wyoming-piper)
            "--data-dir /var/lib/wyoming/piper"
            "--uri tcp://0.0.0.0:10200"
            "--voice en_US-libritts-high"
            "--speaker 0"
          ];
        };
      };

      programs.fish.enable = true;

      environment.shells = with pkgs; [bashInteractive fish];
    };
  };
}

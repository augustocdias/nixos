{den, ...}: let
  u2fKeysFile = ./_u2f_keys;
  u2fKeysExist = builtins.pathExists u2fKeysFile;

  pamAuthConfig = {
    u2fAuth = true;
    fprintAuth = true;
    rules.auth = {
      fprintd = {
        control = "sufficient";
        order = 10800;
      };
      u2f = {
        control = "sufficient";
        order = 10900;
      };
    };
  };
in {
  den.aspects.security = {
    nixos = {
      pkgs,
      lib,
      ...
    }: {
      security = {
        polkit.enable = true;

        pam = {
          u2f = lib.mkIf u2fKeysExist {
            enable = true;
            settings = {
              cue = true;
              authfile = "/etc/u2f_keys";
            };
          };
          services = lib.mkIf u2fKeysExist {
            greetd = pamAuthConfig;
            sudo = pamAuthConfig;
            polkit-1 = pamAuthConfig;
            login = pamAuthConfig;
          };
        };

        tpm2 = {
          enable = true;
          tctiEnvironment.enable = true;
        };
      };

      services = {
        dbus.enable = true;
        pcscd.enable = true;
        udev.packages = [pkgs.yubikey-personalization];
      };

      environment.etc."u2f_keys" = lib.mkIf u2fKeysExist {
        source = u2fKeysFile;
        mode = "0644";
      };

      environment.systemPackages = with pkgs; [
        pam_u2f
        cryptsetup
        tpm2-tools
        libfido2
        gnupg
        pinentry-bemenu
        bemenu
      ];

      # pass-secret-service: D-Bus org.freedesktop.secrets backed by pass/GPG.
      # Pre-built binary — no nixpkgs package available.
      nixpkgs.overlays = [
        (_: prev: let
          version = "0.6.0";
          src = fetchGit {
            url = "https://github.com/grimsteel/pass-secret-service.git";
            ref = "refs/tags/v${version}";
            rev = "b033a419b2fe644df5f8fa9de0a514398eb8428b";
          };
          binary = prev.fetchurl {
            url = "https://github.com/grimsteel/pass-secret-service/releases/download/v${version}/pass-secret-service-x86_64";
            hash = "sha256-A39wgVsLZ4i5bkZzxyFPDnmnvpveR2v9scjytOkD2cI=";
          };
        in {
          pass-secret-service = prev.stdenv.mkDerivation {
            pname = "pass-secret-service";
            inherit version;
            dontUnpack = true;
            nativeBuildInputs = [prev.autoPatchelfHook prev.makeWrapper];
            buildInputs = [prev.stdenv.cc.cc.lib];
            installPhase = ''
              runHook preInstall
              install -Dm755 ${binary} $out/bin/.pass-secret-service-unwrapped
              wrapProgram $out/bin/.pass-secret-service-unwrapped \
                --prefix PATH : "${prev.gnupg}/bin"
              mv $out/bin/.pass-secret-service-unwrapped $out/bin/pass-secret-service
              ln -s $out/bin/pass-secret-service $out/bin/pass_secret_service
              install -Dm644 ${src}/systemd/org.freedesktop.secrets.service \
                $out/share/dbus-1/services/org.freedesktop.secrets.service
              substituteInPlace $out/share/dbus-1/services/org.freedesktop.secrets.service \
                --replace-warn "/usr/bin/pass-secret-service" "$out/bin/pass-secret-service"
              runHook postInstall
            '';
            meta = with prev.lib; {
              description = "Implementation of org.freedesktop.secrets using pass";
              homepage = "https://github.com/grimsteel/pass-secret-service";
              license = licenses.gpl3Only;
              mainProgram = "pass-secret-service";
              platforms = ["x86_64-linux"];
            };
          };
        })
      ];
    };

    homeManager = {pkgs, ...}: let
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
      pinentryPackage =
        if isDarwin
        then pkgs.pinentry_mac
        else pkgs.pinentry-bemenu;
    in {
      programs.gpg = {
        enable = true;
        publicKeys = [
          {
            source = pkgs.fetchurl {
              url = "https://keys.openpgp.org/vks/v1/by-fingerprint/7D8396F74725A208D835CE3730E62A1E4F078650";
              hash = "sha256-v11agJZKThP3/rNN23vyTEwnOk8928JBDlER7Dub4Gc=";
            };
            trust = "ultimate";
          }
        ];
      };

      services.gpg-agent = {
        enable = true;
        enableFishIntegration = true;
        enableSshSupport = true;
        enableExtraSocket = true;
        pinentry.package = pinentryPackage;
        defaultCacheTtl = 1800;
        maxCacheTtl = 7200;
        # Keep extra-socket on both Linux and macOS for SSH agent forwarding.
        extraConfig = ''
          allow-loopback-pinentry
          extra-socket /tmp/S.gpg-agent.extra
        '';
      };
    };
  };
}

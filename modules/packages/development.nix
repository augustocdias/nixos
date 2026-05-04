{den, ...}: {
  den.aspects.development = {
    nixos = {pkgs, ...}: {
      # Allows dynamically linked executables
      programs.nix-ld = {
        enable = true;
        libraries = with pkgs; [
          stdenv.cc.cc
          libz
        ];
      };

      programs.dconf.enable = true;
    };

    homeManager = {
      pkgs,
      lib,
      config,
      ...
    }: {
      services.pass-secret-service = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        enable = true;
      };

      programs.direnv.enable = true;

      programs.password-store = {
        enable = true;
        settings = {
          PASSWORD_STORE_DIR = "${config.home.homeDirectory}/.password-store";
          PASSWORD_STORE_KEY = "7D8396F74725A208D835CE3730E62A1E4F078650";
        };
      };

      home.activation.initPasswordStore = config.lib.dag.entryAfter ["writeBoundary"] ''
        if [ ! -d "${config.home.homeDirectory}/.password-store" ]; then
          ${pkgs.pass}/bin/pass init "7D8396F74725A208D835CE3730E62A1E4F078650"
        fi
      '';

      home.packages = with pkgs; [
        libsecret

        cmake
        gnumake
        ninja
        gcc
        llvm

        nodejs
        python3
        ruby

        cargo
        rustc
        cargo-expand
        cargo-nextest
        cargo-xwin

        git-lfs
        git-cliff
        git-extras
        gh

        jq
        yq-go
        jsonnet
        lnav

        tree-sitter
      ];
    };
  };
}

{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchurl,
}: let
  mkCard = {
    pname,
    version,
    src,
    description,
    homepage,
    file ? "${pname}.js",
    entrypoint ? null,
    # nix-update's --version, read by update-system. "stable" follows releases;
    # "branch" follows the default branch HEAD, for cards upstream never tags.
    #
    # A "branch" card must version as 0-unstable-<date> and pin the FULL rev.
    # nix-update rewrites the old rev across the whole file BEFORE it touches
    # the version, so a short rev embedded in the version string gets replaced
    # by the new sha and the version substitution then no longer matches —
    # leaving version = "0-unstable-<40 hex chars>".
    updatePolicy ? "stable",
  }:
    stdenvNoCC.mkDerivation {
      inherit pname version src;

      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall
        install -Dm444 ${file} -t $out
        runHook postInstall
      '';

      passthru =
        {inherit updatePolicy;}
        // lib.optionalAttrs (entrypoint != null) {inherit entrypoint;};

      meta = {
        inherit description homepage;
        platforms = lib.platforms.all;
      };
    };
in {
  hui-element = mkCard {
    pname = "hui-element";
    version = "0-unstable-2022-05-29";
    src = fetchFromGitHub {
      owner = "thomasloven";
      repo = "lovelace-hui-element";
      rev = "1a805470152c86d9351abc7b0b56ef3ecb7e3a39";
      hash = "sha256-9/xdja3bkFOVbVvlQrtAl8kzPZ0jSMh2ur++k1NMqQY=";
    };
    description = "Use built-in Lovelace elements in places they aren't supported";
    homepage = "https://github.com/thomasloven/lovelace-hui-element";
    updatePolicy = "branch";
  };

  more-info-card = mkCard {
    pname = "more-info-card";
    version = "0-unstable-2021-06-29";
    src = fetchFromGitHub {
      owner = "thomasloven";
      repo = "lovelace-more-info-card";
      rev = "c0a9c942851c1c5370e8de102eb96597fb845d85";
      hash = "sha256-MlUGcW4J0cp8uHHKZVO8BRfdnAARVuEnY+izfuyGmWU=";
    };
    description = "Display the more-info dialog of any entity as a Lovelace card";
    homepage = "https://github.com/thomasloven/lovelace-more-info-card";
    updatePolicy = "branch";
  };

  slider-entity-row = mkCard {
    pname = "slider-entity-row";
    version = "17.5.0";
    src = fetchFromGitHub {
      owner = "thomasloven";
      repo = "lovelace-slider-entity-row";
      tag = "v17.5.0";
      hash = "sha256-1lfYQRi/uW5gbH50yO3l9FUuUmn5mz5rHTPn/fi8fcE=";
    };
    description = "Add sliders for lights, covers and media players to entities cards";
    homepage = "https://github.com/thomasloven/lovelace-slider-entity-row";
  };

  berlin-transport-card = mkCard {
    pname = "berlin-transport-card";
    version = "0-unstable-2026-08-28";
    src = fetchFromGitHub {
      owner = "vas3k";
      repo = "lovelace-berlin-transport-card";
      rev = "78379a612f71d432a5a3bf2107c09d5cd961fea9";
      hash = "sha256-+Al2Pzw0uo+he8acGjf9Ux1p4NnRnlVDdLhsSbq3GXc=";
    };
    file = "dist/berlin-transport-card.js";
    description = "Timetable card for the berlin_transport integration";
    homepage = "https://github.com/vas3k/lovelace-berlin-transport-card";
    updatePolicy = "branch";
  };

  birthday-reminder-card = mkCard {
    pname = "birthday-reminder-card";
    version = "1.0.0";
    src = fetchFromGitHub {
      owner = "vdbrink";
      repo = "homeassistant-lovelace-birthday-reminder-card";
      tag = "v1.0.0";
      hash = "sha256-Qw0t1PTcRMN3829zqbQxcQDIKSzaeL1pN+Bm2CZDNEg=";
    };
    # Upstream names the file after the card, not the repo.
    file = "birthday-card.js";
    entrypoint = "birthday-card.js";
    description = "Birthday reminder card";
    homepage = "https://github.com/vdbrink/homeassistant-lovelace-birthday-reminder-card";
  };

  status-card = stdenvNoCC.mkDerivation rec {
    pname = "status-card";
    version = "3.3.2";

    src = fetchurl {
      url = "https://github.com/xBourner/status-card/releases/download/v${version}/status-card.js";
      hash = "sha256-djkwzLoSDO+UYSSK6goaehCGMc/65ouSBeDQsQlAaeA=";
    };

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall
      install -Dm444 $src $out/status-card.js
      runHook postInstall
    '';

    meta = {
      description = "Card showing the status of entities grouped by domain";
      homepage = "https://github.com/xBourner/status-card";
      platforms = lib.platforms.all;
    };
  };
}

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
  }:
    stdenvNoCC.mkDerivation ({
        inherit pname version src;

        dontConfigure = true;
        dontBuild = true;

        installPhase = ''
          runHook preInstall
          install -Dm444 ${file} -t $out
          runHook postInstall
        '';

        meta = {
          inherit description homepage;
          platforms = lib.platforms.all;
        };
      }
      // lib.optionalAttrs (entrypoint != null) {
        passthru = {inherit entrypoint;};
      });
in {
  hui-element = mkCard {
    pname = "hui-element";
    version = "0-unstable-1a80547";
    src = fetchFromGitHub {
      owner = "thomasloven";
      repo = "lovelace-hui-element";
      rev = "1a80547";
      hash = "sha256-9/xdja3bkFOVbVvlQrtAl8kzPZ0jSMh2ur++k1NMqQY=";
    };
    description = "Use built-in Lovelace elements in places they aren't supported";
    homepage = "https://github.com/thomasloven/lovelace-hui-element";
  };

  more-info-card = mkCard {
    pname = "more-info-card";
    version = "0-unstable-c0a9c94";
    src = fetchFromGitHub {
      owner = "thomasloven";
      repo = "lovelace-more-info-card";
      rev = "c0a9c94";
      hash = "sha256-MlUGcW4J0cp8uHHKZVO8BRfdnAARVuEnY+izfuyGmWU=";
    };
    description = "Display the more-info dialog of any entity as a Lovelace card";
    homepage = "https://github.com/thomasloven/lovelace-more-info-card";
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
    version = "0-unstable-78379a6";
    src = fetchFromGitHub {
      owner = "vas3k";
      repo = "lovelace-berlin-transport-card";
      rev = "78379a6";
      hash = "sha256-+Al2Pzw0uo+he8acGjf9Ux1p4NnRnlVDdLhsSbq3GXc=";
    };
    file = "dist/berlin-transport-card.js";
    description = "Timetable card for the berlin_transport integration";
    homepage = "https://github.com/vas3k/lovelace-berlin-transport-card";
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

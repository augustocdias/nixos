{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}: let
  mkTheme = {
    pname,
    version,
    src,
    description,
    homepage,
  }:
    stdenvNoCC.mkDerivation {
      inherit pname version src;

      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall
        mkdir -p "$out/themes"
        find themes -maxdepth 1 -name '*.yaml' -exec cp -t "$out/themes" {} +
        runHook postInstall
      '';

      passthru.isHomeAssistantTheme = true;

      meta = {
        inherit description homepage;
        platforms = lib.platforms.all;
      };
    };
in {
  ios-themes = mkTheme {
    pname = "ios-themes";
    version = "3.0.3";
    src = fetchFromGitHub {
      owner = "basnijholt";
      repo = "lovelace-ios-themes";
      tag = "v3.0.3";
      hash = "sha256-3jaG48cFAAAEYx7v9NaaP/CJuNNnAw4yHC/cmWZCepw=";
    };
    description = "iOS-like themes for Home Assistant";
    homepage = "https://github.com/basnijholt/lovelace-ios-themes";
  };

  macos-theme = mkTheme {
    pname = "macos-theme";
    version = "1.4";
    src = fetchFromGitHub {
      owner = "JuanMTech";
      repo = "macOS-Theme";
      tag = "v1.4";
      hash = "sha256-3HOUXkAIdk0eRM91V9TgmNxR84yjx53r4EY13SbutEQ=";
    };
    description = "macOS-inspired theme for Home Assistant";
    homepage = "https://github.com/JuanMTech/macOS-Theme";
  };

  frosted-glass-themes = mkTheme {
    pname = "frosted-glass-themes";
    version = "1.3";
    src = fetchFromGitHub {
      owner = "wessamlauf";
      repo = "homeassistant-frosted-glass-themes";
      tag = "v1.3";
      hash = "sha256-LttvLCnn9Necem2BkVVDHpEmBDeiLpqBvi59h92r0i4=";
    };
    description = "Frosted glass themes for Home Assistant";
    homepage = "https://github.com/wessamlauf/homeassistant-frosted-glass-themes";
  };
}

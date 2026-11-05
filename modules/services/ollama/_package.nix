{
  fetchurl,
  stdenvNoCC,
  lib,
}: let
  version = "0.40.15";
  archive = fetchurl {
    url = "https://github.com/ollama/ollama/releases/download/v${version}/ollama-darwin.tgz";
    hash = "sha256-YHx51dYxXvnYltuDrd5zakwAVxljKYQ1ROebla+yYKg=";
  };
in {
  # Native fetcher on each platform; nix-update changes this single pin.
  source =
    archive
    // {
      inherit version;
      src = archive;
      updatePolicy = "stable";
      updateFile = "modules/services/ollama/_package.nix";
    };
  package = stdenvNoCC.mkDerivation {
    pname = "ollama-bin";
    inherit version;
    src = archive;
    dontFixup = true;
    phases = ["unpackPhase" "installPhase"];
    unpackPhase = ''
      runHook preUnpack
      mkdir payload
      tar -xzf "$src" -C payload
      runHook postUnpack
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/libexec" "$out/bin"
      cp -a payload "$out/libexec/ollama"
      ln -s "$out/libexec/ollama/ollama" "$out/bin/ollama"
      runHook postInstall
    '';
    meta = {
      description = "Official headless Ollama release, including MLX runtimes";
      homepage = "https://github.com/ollama/ollama";
      license = lib.licenses.mit;
      platforms = lib.platforms.darwin;
      mainProgram = "ollama";
    };
  };
}

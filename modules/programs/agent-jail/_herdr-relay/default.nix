{
  lib,
  stdenvNoCC,
  python3,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  pname = "agent-herdr-relay";
  version = "0.1.0";

  dontUnpack = true;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/herdr-relay $out/bin
    cp ${./server.py} $out/lib/herdr-relay/server.py
    makeWrapper ${python3}/bin/python3 $out/bin/agent-herdr-relay \
      --add-flags "$out/lib/herdr-relay/server.py"
    runHook postInstall
  '';

  meta = {
    description = "Restricted Herdr sidebar reporting relay for jailed coding agents";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "agent-herdr-relay";
  };
}

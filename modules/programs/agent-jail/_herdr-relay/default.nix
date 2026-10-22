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
  nativeCheckInputs = [python3];
  doCheck = true;

  checkPhase = ''
    runHook preCheck
    cp ${./server.py} server.py
    cp ${./test_relay.py} test_relay.py
    python3 -m unittest discover -s . -p 'test_*.py'
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/herdr-relay $out/bin
    cp ${./server.py} $out/lib/herdr-relay/server.py
    makeWrapper ${python3}/bin/python3 $out/bin/agent-herdr-relay \
      --add-flags "$out/lib/herdr-relay/server.py"
    runHook postInstall
  '';

  meta = {
    description = "Restricted Herdr reporting relay for jailed coding agents";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "agent-herdr-relay";
  };
}

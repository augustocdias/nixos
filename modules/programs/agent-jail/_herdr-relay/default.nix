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
    cp ${./app_proxy.py} app_proxy.py
    cp ${./test_app_proxy.py} test_app_proxy.py
    python3 -m unittest test_app_proxy
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/herdr-relay $out/bin
    cp ${./server.py} $out/lib/herdr-relay/server.py
    cp ${./app_proxy.py} $out/lib/herdr-relay/app_proxy.py
    makeWrapper ${python3}/bin/python3 $out/bin/agent-herdr-relay \
      --add-flags "$out/lib/herdr-relay/server.py"
    makeWrapper ${python3}/bin/python3 $out/bin/agent-herdr-app-proxy \
      --add-flags "$out/lib/herdr-relay/app_proxy.py"
    runHook postInstall
  '';

  meta = {
    description = "Restricted Herdr reporting relay and App proxy for jailed coding agents";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "agent-herdr-relay";
  };
}

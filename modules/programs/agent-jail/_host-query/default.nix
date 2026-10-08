{
  lib,
  stdenvNoCC,
  python3,
  systemd,
  bindfs,
  makeWrapper,
}:
stdenvNoCC.mkDerivation {
  pname = "agent-host-query";
  version = "0.1.0";

  dontUnpack = true;

  nativeBuildInputs = [makeWrapper];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/host-query $out/bin
    cp ${./server.py} $out/lib/host-query/server.py
    makeWrapper ${python3}/bin/python3 $out/bin/agent-host-query \
      --add-flags "$out/lib/host-query/server.py" \
      --prefix PATH : ${lib.makeBinPath [systemd bindfs]}
    runHook postInstall
  '';

  meta = {
    description = "Host-side query service for jailed coding agents (opencode, claude)";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "agent-host-query";
  };
}

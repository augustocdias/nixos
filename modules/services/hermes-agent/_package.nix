{
  lib,
  hermesInput,
  honchoSource,
  system,
}: let
  base = hermesInput.packages.${system}.messaging;
  python = base.python;
  upstreamUv2nix = hermesInput.inputs.uv2nix;
  # Upstream's wheel omits the bridge; both CLI pairing and the gateway resolve it here.
  uv2nix =
    upstreamUv2nix
    // {
      lib =
        upstreamUv2nix.lib
        // {
          workspace =
            upstreamUv2nix.lib.workspace
            // {
              loadWorkspace = args: let
                workspace = upstreamUv2nix.lib.workspace.loadWorkspace args;
              in
                workspace
                // {
                  mkPyprojectOverlay = args:
                    lib.composeExtensions (workspace.mkPyprojectOverlay args) (_final: prev: {
                      hermes-agent = prev.hermes-agent.overrideAttrs (old: {
                        postInstall =
                          (old.postInstall or "")
                          + ''
                            mkdir -p "$out/${python.sitePackages}/scripts"
                            cp -r ${hermesInput}/scripts/whatsapp-bridge "$out/${python.sitePackages}/scripts/"
                            patch -d "$out/${python.sitePackages}" -p1 < ${./_whatsapp-bridge.patch}
                          '';
                      });
                    });
                };
            };
        };
    };
  sdkVersion = (builtins.fromTOML (builtins.readFile "${honchoSource}/sdks/python/pyproject.toml")).project.version;
  sdk = python.pkgs.buildPythonPackage {
    pname = "honcho-ai";
    version = sdkVersion;
    src = "${honchoSource}/sdks/python";
    pyproject = true;
    build-system = [python.pkgs.setuptools python.pkgs.wheel];
    # Runtime requirements come from Hermes's sealed environment, not nixpkgs.
    dontCheckRuntimeDeps = true;
    doCheck = false;
    postInstall = ''
      PYTHONPATH="$out/${python.sitePackages}" ${base.hermesVenv}/bin/python - <<'PY'
      from importlib.metadata import distribution, version
      from packaging.requirements import Requirement
      import honcho
      sdk = distribution("honcho-ai")
      assert sdk.version == ${builtins.toJSON sdkVersion}
      for raw in sdk.requires:
          requirement = Requirement(raw)
          if requirement.marker is None or requirement.marker.evaluate({"extra": ""}):
              assert requirement.specifier.contains(version(requirement.name)), raw
      PY
    '';
    meta.license = lib.licenses.asl20;
  };
in
  base.override {
    version = "unstable-${hermesInput.shortRev}";
    inherit uv2nix;
    extraPythonPackages = [sdk];
  }

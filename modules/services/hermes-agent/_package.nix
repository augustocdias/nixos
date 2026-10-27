{
  lib,
  hermesInput,
  honchoSource,
  system,
}: let
  base = hermesInput.packages.${system}.messaging;
  python = base.python;
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
    extraPythonPackages = [sdk];
  }

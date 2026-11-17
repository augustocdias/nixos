{
  lib,
  hermesInput,
  system,
  # The macmini's WhatsApp pairing needs the bridge; other hosts take upstream's wheel as is.
  whatsappBridge ? true,
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
in
  base.override {
    version = "unstable-${hermesInput.shortRev}";
    uv2nix =
      if whatsappBridge
      then uv2nix
      else upstreamUv2nix;
  }

{
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
      let
        hassPython = pkgs.home-assistant.python3Packages;

        ha-mcp-tools = pkgs.callPackage ./_ha-mcp.nix {
          python3Packages = hassPython;
        };

        berlin-transport = pkgs.callPackage ./_berlin-transport.nix {
          inherit (hassPython) async-timeout;
        };
      in
        lib.mapAttrs' (name: lib.nameValuePair "hass-${name}")
        (lib.filterAttrs (_: lib.isDerivation) (
          {inherit berlin-transport ha-mcp-tools;}
          // (pkgs.callPackage ./_lovelace-modules.nix {})
          // (pkgs.callPackage ./_themes.nix {})
        ))
    );
  };
}

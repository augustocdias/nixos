{
  den,
  lib,
  ...
}: let
  version = "0.6.0";
in {
  den.aspects.jgrep = {
    homeManager = {pkgs, lib, ...}: let
      jgrep = pkgs.stdenvNoCC.mkDerivation {
        pname = "jgrep";
        inherit version;

        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/jevgrep/-/jevgrep-${version}.tgz";
          hash = "sha256-CXhFmil3Zpip/6eWyKY6Bxng3W/Hqwh5l1fD1iJ7M6M=";
        };

        nativeBuildInputs = [pkgs.makeWrapper];

        unpackPhase = ''
          tar xzf $src --strip-components=1
        '';

        installPhase = ''
          mkdir -p $out/lib/jgrep $out/share/jgrep
          cp dist/jgrep.js $out/lib/jgrep/jgrep.js
          cp -r skills/jgrep/SKILL.md $out/share/jgrep/SKILL.md

          makeWrapper ${lib.getExe pkgs.nodejs} $out/bin/jgrep \
            --add-flags "$out/lib/jgrep/jgrep.js"
        '';

        passthru.updateFile = "modules/programs/jgrep.nix";

        meta = {
          description = "Semantic grep: describe the code you want in English, get file:line hits";
          homepage = "https://github.com/kyu1204/jgrep";
          license = lib.licenses.mit;
          mainProgram = "jgrep";
        };
      };
    in {
      home.packages = [jgrep];

      # Skill for OpenCode agents.
      xdg.configFile."opencode/skills/jgrep/SKILL.md".source =
        "${jgrep}/share/jgrep/SKILL.md";

      # Ensure the cache dir exists so the jail's try-rw-bind picks it up.
      home.activation.jgrep-cache = lib.hm.dag.entryAfter ["writeBoundary"] ''
        mkdir -p "$HOME/.cache/jgrep"
      '';
    };
  };
}

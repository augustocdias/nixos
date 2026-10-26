{
  lib,
  pkgs,
}: let
  source = ./dev-skills;
  names = builtins.filter (name: builtins.pathExists (source + "/${name}/SKILL.md")) (builtins.attrNames (builtins.readDir source));
  package = pkgs.runCommand "dev-skills" {} ''
    mkdir -p "$out"
    cp -R ${source}/. "$out/"
    chmod -R u+w "$out"
    for skill in "$out"/*/SKILL.md; do
      directory="$(dirname "$skill")"
      cp "$out/WORKFLOW.md" "$out/LICENSE" "$out/UPSTREAM.md" "$directory/"
    done
  '';
in {
  inherit package;
  skills = lib.genAttrs names (name: "${package}/${name}");
}

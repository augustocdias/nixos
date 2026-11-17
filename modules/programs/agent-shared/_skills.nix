{
  lib,
  pkgs,
  exclude ? [],
}: let
  source = ./skills;
  names = builtins.filter (name: !(builtins.elem name exclude) && builtins.pathExists (source + "/${name}/SKILL.md")) (builtins.attrNames (builtins.readDir source));
  package = pkgs.runCommand "agent-skills" {} ''
    mkdir -p "$out"
    cp ${source}/WORKFLOW.md "$out/"
    ${lib.concatMapStringsSep "\n" (name: ''cp -R ${source}/${name} "$out/${name}"'') names}
    chmod -R u+w "$out"
    for skill in "$out"/*/SKILL.md; do
      directory="$(dirname "$skill")"
      cp "$out/WORKFLOW.md" "$directory/"
    done
  '';
in {
  inherit package;
  skills = lib.genAttrs names (name: "${package}/${name}");
}

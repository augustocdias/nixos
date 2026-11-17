# Wiki gate plugin with this host's vault policy. Each host writes only its own tree.
{
  pkgs,
  lib,
  home,
  host,
  recallOnly ? [],
}: let
  wikis = import ./_wikis.nix;
  mine = wikis.trees.${host};
  # Policy for this host's trees; the other host's trees in the same vault stay read-only.
  vaults = map (vault: {
    root = "${home}/${vault}";
    trees = lib.genAttrs (wikis.treesIn vault) (tree:
      lib.optionalAttrs (mine ? ${tree}) {
        inherit (mine.${tree}) librarian;
        writers = [mine.${tree}.writer];
      });
  }) (lib.unique (lib.mapAttrsToList (_: wiki: wiki.vault) mine));
in
  pkgs.runCommand "wiki-gate" {} ''
    mkdir -p $out
    cp ${./wiki-gate}/*.py ${./wiki-gate}/plugin.yaml $out/
    cp ${pkgs.writeText "settings.json" (builtins.toJSON {
      inherit vaults;
      # Profiles with hwiki recall that must not file memory.
      recall_only = recallOnly;
      manual_prefix = "manual:";
      git = lib.getExe pkgs.git;
    })} $out/settings.json
  ''

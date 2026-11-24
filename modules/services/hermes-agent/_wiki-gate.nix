# Wiki gate plugin with this host's vault policy. A tree's librarian writes only on its curator host;
# every host that mounts a tree lets the tree's writers file sources into raw/.
{
  pkgs,
  lib,
  home,
  host,
  recallOnly ? [],
}: let
  wikis = import ./_wikis.nix;
  mine = wikis.on host;
  vaults =
    map (vault: {
      root = "${home}/${vault}";
      trees = lib.listToAttrs (map (wiki:
        lib.nameValuePair wiki.tree {
          inherit (wiki) dir writers;
          librarian =
            if wiki.curator == host
            then wiki.librarian
            else null;
        }) (lib.filter (wiki: wiki.vault == vault) mine));
    })
    (lib.unique (map (wiki: wiki.vault) mine));
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

# Wiki trees: the vault (home-relative), the folder inside it ("" for the vault root), the hosts that
# mount it, the host whose librarian curates it, the profiles that file sources into its raw/ folder,
# and the domain the librarian writes into SCHEMA.md. Other hosts only file sources and recall.
let
  trees = {
    augusto = {
      vault = "obsidian-vault";
      dir = "";
      hosts = ["laptop" "macmini" "vps-hermes"];
      # limit: the laptop curates until the VPS takes over; set "vps-hermes" at cutover, which drops the laptop's librarian.
      curator = "laptop";
      librarian = "librarian";
      writers = ["default" "coordinator"];
      domain = "software engineering and AI research (systems, architecture, tools, practices, agents, models, techniques and papers), plus personal and household knowledge (home, devices, health, finance, travel, hobbies, people), home automation, self-hosting, NixOS and personal tech projects. Nothing company-specific";
    };
    # Livia's vault never leaves the macmini: local Git history, no remote and no token.
    livia = {
      vault = "livia-vault";
      dir = "livia";
      hosts = ["macmini"];
      curator = "macmini";
      librarian = "librarian-livia";
      writers = ["livia"];
      domain = "broad personal knowledge";
      local = true;
    };
  };
  named = builtins.mapAttrs (tree: wiki: wiki // {inherit tree;}) trees;
  # A path inside the tree, relative to its vault.
  sub = wiki: path:
    if wiki.dir == ""
    then path
    else "${wiki.dir}/${path}";
in {
  trees = named;
  inherit sub;
  on = host: builtins.filter (wiki: builtins.elem host wiki.hosts) (builtins.attrValues named);
  soul = file: wiki:
    builtins.replaceStrings ["@tree@" "@vault@" "@path@" "@domain@" "@librarian@"] [
      wiki.tree
      wiki.vault
      (sub wiki "")
      wiki.domain
      wiki.librarian
    ]
    (builtins.readFile file);
}

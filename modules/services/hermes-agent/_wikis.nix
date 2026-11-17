# Wiki trees per host: the vault (home-relative), the librarian that curates the tree, the chat
# profile that files sources into its raw/ folder, and the domain the librarian writes into SCHEMA.md.
let
  trees = {
    laptop.work = {
      vault = "obsidian-vault";
      librarian = "librarian";
      writer = "coordinator";
      domain = "software engineering and AI research: systems, architecture, tools, practices, agents, models, techniques and papers. Nothing company-specific";
    };
    macmini = {
      home = {
        vault = "obsidian-vault";
        librarian = "librarian";
        writer = "augusto";
        domain = "personal and household knowledge (home, devices, health, finance, travel, hobbies, people), plus home automation, self-hosting, NixOS and personal tech projects";
      };
      # Livia's vault never leaves the macmini: local Git history, no remote and no token.
      livia = {
        vault = "livia-vault";
        librarian = "librarian-livia";
        writer = "livia";
        domain = "broad personal knowledge";
        local = true;
      };
    };
  };
  named = builtins.mapAttrs (_: builtins.mapAttrs (tree: wiki: wiki // {inherit tree;})) trees;
  all = builtins.foldl' (a: b: a // b) {} (builtins.attrValues named);
in {
  trees = named;
  # Every tree in a vault, on any host: each host reads the others' trees.
  treesIn = vault: builtins.filter (tree: all.${tree}.vault == vault) (builtins.attrNames all);
  soul = file: wiki:
    builtins.replaceStrings ["@tree@" "@vault@" "@domain@" "@librarian@"] [wiki.tree wiki.vault wiki.domain wiki.librarian]
    (builtins.readFile file);
}

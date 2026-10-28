{
  den.aspects.rtk = {
    homeManager = {
      pkgs,
      lib,
      ...
    }: {
      # Full edition (default `engine` feature) from nixpkgs. Wired into the
      # harnesses by claude-code.nix (PreToolUse hook) and omp.nix (extension);
      # never run `rtk init`, which would rewrite Nix-owned files.
      home.packages = [pkgs.rtk];

      # The jail binds this dir so `rtk gain` history survives sessions;
      # try-rw-bind skips a missing source.
      home.activation.rtk-dirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
        mkdir -p "$HOME/.local/share/rtk"
      '';
    };
  };
}

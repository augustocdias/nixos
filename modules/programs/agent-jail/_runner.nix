# Jail wrapper the host link puts in front of programs without their own:
# `hc run --on host -- npm run dev` runs `agent-jail-run npm run dev` on the host.
# Both harness modules install it; the identical store path deduplicates.
mkJail: pkgs:
mkJail {
  name = "agent-jail-run";
  # The sidebar bridge speaks for harnesses; plain programs report status over OSC themselves.
  reportActivity = false;
  package = pkgs.writeShellScriptBin "agent-jail-run" ''
    # `hc run --on host` without a command asks for the machine's shell.
    if [ "$#" -eq 0 ]; then
      set -- "''${SHELL:-bash}"
    fi
    exec "$@"
  '';
}

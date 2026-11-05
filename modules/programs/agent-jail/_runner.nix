# Jail wrapper for programs without their own, so work started through the
# user's Core stays jailed: `hc run -- agent-jail-run npm run dev`.
# Both harness modules install it; the identical store path deduplicates.
mkJail: pkgs:
mkJail {
  name = "agent-jail-run";
  # The sidebar bridge speaks for harnesses; plain programs report status over OSC themselves.
  reportActivity = false;
  package = pkgs.writeShellScriptBin "agent-jail-run" ''
    # Without a command, a jailed shell.
    if [ "$#" -eq 0 ]; then
      set -- "''${SHELL:-bash}"
    fi
    exec "$@"
  '';
}

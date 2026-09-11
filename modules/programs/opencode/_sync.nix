# Identifier tying the two halves of the jailed setup together.
#
# The sandbox ships as a package (jail/jail.nix) while the config it describes
# ships through home.activation and xdg.configFile. Build one without the other
# and the sandbox keeps working while jail-context.md, the bash allowlist and
# the host_* tools silently disagree with it — an agent then reads a document
# that is no longer true. The jail bakes this value in, activation writes the
# same value next to the deployed tools, and the launcher refuses to start when
# they differ.
#
# Any edit to a file below changes the hash, so the two halves can only agree
# when they come from the same evaluation.
let
  files = [
    ./_permissions.nix
    ./_agents.nix
    ./tools/host.ts
    ./jail/jail-context.md
    ./jail/jail.nix
  ];
in
  builtins.hashString "sha256" (
    builtins.concatStringsSep "\n" (map (f: builtins.hashFile "sha256" f) files)
  )

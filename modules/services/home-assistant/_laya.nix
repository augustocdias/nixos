{
  lib,
  buildHomeAssistantComponent,
}:
# Our own conversation agent, sourced from this repo (./laya). It is a client
# of the laya.serve endpoint the macmini runs (aspect `laya`); see AGENTS.md.
# Not in pins.nix: there is no upstream to track.
buildHomeAssistantComponent {
  owner = "augustocdias";
  domain = "laya";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./laya;
    fileset = lib.fileset.fileFilter (f: f.hasExt "py" || f.hasExt "json") ./laya;
  };

  meta = {
    description = "Local System One (Laya) conversation agent with LLM fallback";
    license = lib.licenses.mit;
  };
}

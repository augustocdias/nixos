# Declarative herdr plugin installation.
#
# `herdr plugin install` clones from GitHub and runs the manifest's [[build]]
# commands at install time, which needs network and a toolchain. Here nix does
# the build instead, the [[build]] section is stripped from the installed
# manifest, and every remaining command is prefixed with a wrapper that puts
# `runtimeDeps` on PATH — plugins call their dependencies from nested scripts
# and some resolve binaries by PATH name, so rewriting argv[0] is not enough.
{
  pkgs,
  lib,
}: let
  sanitize = lib.replaceStrings ["." ":" "/" " "] ["-" "-" "-" "-"];
in {
  mkHerdrPlugin = {
    src,
    subdir ? null,
    runtimeDeps ? [],
    build ? "auto",
    npmDepsHash ? null,
    nativeBuildInputs ? [],
    commands ? {},
    env ? {},
  }: let
    root =
      if subdir == null
      then src
      else "${src}/${subdir}";

    manifest = builtins.fromTOML (builtins.readFile "${root}/herdr-plugin.toml");
    slug = sanitize manifest.id;
    pname = "herdr-plugin-${slug}";

    nodeManifest =
      if builtins.pathExists "${root}/package.json"
      then builtins.fromJSON (builtins.readFile "${root}/package.json")
      else {};
    nodeName = nodeManifest.name or slug;
    nodeNeedsBuild =
      ((nodeManifest.scripts or {}) ? build) || ((nodeManifest.dependencies or {}) != {});

    cargoLockPath = "${root}/Cargo.lock";
    hasNpmLock = builtins.pathExists "${root}/package-lock.json";

    strategy =
      if build != "auto"
      then build
      else if builtins.pathExists "${root}/Cargo.toml"
      then "rust"
      else if nodeNeedsBuild
      then "node"
      else "none";

    artifacts =
      if strategy == "rust"
      then
        assert lib.assertMsg (builtins.pathExists cargoLockPath)
        "mkHerdrPlugin: ${manifest.id} has no Cargo.lock, so its dependencies cannot be vendored without a hash";
          pkgs.rustPlatform.buildRustPackage {
            inherit pname nativeBuildInputs;
            version = manifest.version;
            src = root;
            cargoLock.lockFile = cargoLockPath;
          }
      else if strategy == "node"
      then
        assert lib.assertMsg (hasNpmLock || npmDepsHash != null)
        "mkHerdrPlugin: ${manifest.id} has dependencies but no package-lock.json; pass npmDepsHash (a bun.lock alone cannot be fetched without one)";
          pkgs.buildNpmPackage ({
              inherit pname nativeBuildInputs;
              version = manifest.version;
              src = root;
            }
            // (
              if hasNpmLock
              then {
                npmDeps = pkgs.importNpmLock {npmRoot = root;};
                inherit (pkgs.importNpmLock) npmConfigHook;
              }
              else {inherit npmDepsHash;}
            ))
      else null;

    execName = "herdr-plugin-exec-${slug}";
    execDeps = runtimeDeps ++ lib.optional (artifacts != null) artifacts;
    exec = pkgs.writers.writeFishBin execName ''
      ${lib.concatStrings (lib.mapAttrsToList (name: value: "set -gx ${name} ${lib.escapeShellArg (toString value)}\n") env)}${
        lib.optionalString (execDeps != [])
        "set -gx PATH ${lib.concatMapStringsSep " " (dep: lib.escapeShellArg "${dep}/bin") execDeps} $PATH\n"
      }exec $argv
    '';

    withWrapper = entry:
      entry
      // {
        command =
          ["${exec}/bin/${execName}"]
          ++ (
            if entry ? id
            then commands.${entry.id} or entry.command
            else entry.command
          );
      };

    patched =
      builtins.removeAttrs manifest ["build"]
      // lib.optionalAttrs (manifest ? actions) {actions = map withWrapper manifest.actions;}
      // lib.optionalAttrs (manifest ? panes) {panes = map withWrapper manifest.panes;}
      // lib.optionalAttrs (manifest ? startup) {startup = map withWrapper manifest.startup;}
      // lib.optionalAttrs (manifest ? events) {events = map withWrapper manifest.events;};
  in
    assert lib.assertMsg (lib.versionAtLeast pkgs.herdr.version (manifest.min_herdr_version or "0"))
    "mkHerdrPlugin: ${manifest.id} needs herdr >= ${manifest.min_herdr_version}, but herdr is ${pkgs.herdr.version}";
      pkgs.runCommand "${pname}-${manifest.version}" {
        passthru = {
          pluginId = manifest.id;
          skills =
            if builtins.pathExists "${root}/skills"
            then "${root}/skills"
            else null;
        };
      } ''
        mkdir -p $out
        cp -r ${root}/. $out/
        chmod -R u+w $out
        cp ${(pkgs.formats.toml {}).generate "herdr-plugin.toml" patched} $out/herdr-plugin.toml
        printf '%s' ${lib.escapeShellArg manifest.id} > $out/.herdr-plugin-id
        ${lib.optionalString (strategy == "rust") ''
          mkdir -p $out/target/release
          ln -st $out/target/release ${artifacts}/bin/*
        ''}
        ${lib.optionalString (strategy == "node") ''
          for candidate in dist build lib node_modules; do
            source_path=${artifacts}/lib/node_modules/${nodeName}/$candidate
            [ -e "$source_path" ] && ln -sfn "$source_path" $out/$candidate
          done
          true
        ''}
      '';
}

# What differs between the Hermes hosts. _work.nix builds the same profiles on every host and reads the
# host's entry here, as it reads _models.nix and _fallbacks.nix.
{
  inputs,
  lib,
  pkgs,
  homeDirectory,
  osConfig,
}: let
  # limit: assumes the Hermes user's uid (1000, 1001 for vps-hermes's hermes user); derive it if a uid changes.
  runtimeDir = "/run/user/1000";
  # pnpm reads registry auth from this file instead of ~/.npmrc, which the sandbox hides.
  npmrcAuth = pkgs.writeText "npmrc" "//npm.pkg.github.com/:_authToken=\${NELLY_GH_REGISTRY_TOKEN}\n";
in rec {
  laptop = {
    # Terminal commands and file tools run in the bubblewrap sandbox; _work.nix sets its binds and limits.
    terminal = "bubblewrap";
    executionSoul = ./souls/_linux.md;
    # Workers use the agent Git identity through the sandbox; the user's own Git stays on the YubiKey.
    agentGit = false;
    desktop = true;
    # Official plugins linked into every profile; each profile enables only the ones it uses.
    plugins = ["advanced-delegation" "bubblewrap" "hermes-security" "rea"];
    provider = "${inputs.hermes-official-plugins}/claude-subscription-directsdk";
    whatsappBridge = false;
    # Linear, Notion and Datadog for the coordinator (full) and the roles (read tools).
    workMcp = true;
    # People profiles besides augusto, who is the root (default) profile.
    persons = [];
    homeassistant = [];
    inherit runtimeDir;
    gitAgentDir = "${runtimeDir}/hermes-git";
    # Exported by the hermes wrapper, so the gateway and every sandbox see them.
    wrapperEnv = {
      CLAUDE_SUBSCRIPTION_DIRECTSDK_COMMAND = lib.getExe pkgs.claude-code;
      HERMES_SECURITY_OSV_SCANNER = lib.getExe pkgs.osv-scanner;
      NIX_REMOTE = "daemon";
      DOCKER_HOST = "unix://${runtimeDir}/podman/podman.sock";
      CONTAINER_HOST = "unix://${runtimeDir}/podman/podman.sock";
      PNPM_CONFIG_NPMRC_AUTH_FILE = "${npmrcAuth}";
    };
    # The sandbox refuses a missing bind source; these sockets appear only once their services start.
    wrapperDirs = ["${runtimeDir}/podman"];
    apiServer = null;
  };
  macmini = {
    terminal = "local";
    executionSoul = ./souls/_darwin.md;
    agentGit = false;
    desktop = true;
    plugins = ["advanced-delegation" "homeassistant"];
    provider = null;
    whatsappBridge = true;
    workMcp = false;
    persons = ["livia"];
    homeassistant = ["default" "coordinator" "livia"];
    runtimeDir = null;
    gitAgentDir = "${homeDirectory}/.local/state/hermes-git";
    wrapperEnv = {};
    wrapperDirs = [];
    # Loopback OpenAI-compatible listener for Open WebUI and voice: the root serves /v1, each person /p/<name>/v1.
    apiServer = {
      port = "8650";
      keys = {
        default = osConfig.sops.secrets.hermes_augusto_api_key.path;
        livia = osConfig.sops.secrets.hermes_livia_api_key.path;
      };
    };
  };
  # The laptop's Hermes on a VPS, run locally by the unprivileged hermes user, without the bubblewrap
  # sandbox or the work MCPs.
  vps-hermes = let
    runtimeDir = "/run/user/1001";
    podman = "unix://${runtimeDir}/podman/podman.sock";
  in
    laptop
    // {
      inherit runtimeDir;
      gitAgentDir = "${runtimeDir}/hermes-git";
      wrapperDirs = ["${runtimeDir}/podman"];
      terminal = "local";
      executionSoul = ./souls/_server.md;
      plugins = lib.remove "bubblewrap" laptop.plugins;
      workMcp = false;
      # Headless: Desktop connects from the clients over SSH.
      desktop = false;
      # pnpm's work registry auth exists for the sandbox, which hides ~/.npmrc.
      wrapperEnv =
        builtins.removeAttrs laptop.wrapperEnv ["PNPM_CONFIG_NPMRC_AUTH_FILE"]
        // {
          DOCKER_HOST = podman;
          CONTAINER_HOST = podman;
        };
      # No YubiKey on the server: the user's own Git signs and pushes with the agent key.
      agentGit = true;
    };
}

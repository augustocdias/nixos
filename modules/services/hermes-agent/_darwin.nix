# macmini: the household Hermes as a system LaunchDaemon.
{
  inputs,
  lib,
  models,
  fallbacks,
}: {
  config,
  pkgs,
  ...
}: let
  home = "/Users/augusto";
  root = "${home}/.hermes";
  package = import ./_package.nix {
    inherit lib;
    hermesInput = inputs.hermes-agent;
    honchoSource = inputs.honcho;
    system = pkgs.stdenv.hostPlatform.system;
  };
  userHome = config.home-manager.users.augusto.home;
  manifest = pkgs.writeText "hermes-household-profiles.json" (builtins.toJSON {
    host_config.gateway.multiplex_profiles = true;
    profile_configs = lib.genAttrs ["augusto" "livia"] (name: {
      model = models.macmini.${name};
      auxiliary.compression = {
        provider = "main";
        model = "";
      };
      fallback_providers = fallbacks.macmini.${name};
      memory.provider = "honcho";
      mcp_servers = {
        context7 = {
          url = "https://mcp.context7.com/mcp";
          trust = "untrusted";
        };
      };
    });
    soul = ./SOUL.md;
    host_key = config.sops.secrets.hermes_host_api_key.path;
    mcp_secrets = {};
    profile_env.HASS_URL = "http://home.local:8123";
    profile_keys = {
      augusto = config.sops.secrets.hermes_augusto_api_key.path;
      livia = config.sops.secrets.hermes_livia_api_key.path;
    };
    plugins = {
      honcho = "${inputs.hermes-plugin-honcho}/hermes-plugin-honcho";
      advanced-delegation = "${inputs.hermes-official-plugins}/advanced-delegation";
      homeassistant = "${inputs.hermes-official-plugins}/homeassistant";
      office-3d = "${inputs.hermes-plugin-office-3d}";
      ponytail = "${inputs.ponytail}";
      # Upstream's adapter, version-matched to the binary: rewrites `terminal`
      # commands through `rtk rewrite`. Hermes's dangerous-command checks run
      # on the rewritten command.
      rtk-rewrite = "${pkgs.rtk.src}/hooks/hermes/rtk-rewrite";
    };
    enabled_plugins = ["rtk-rewrite" "ponytail" "advanced-delegation" "homeassistant" "office-3d"];
    skills = {
      caveman-bundle = "${inputs.caveman}/skills";
    };
    honcho_keys = "/var/lib/honcho/app/keys";
    honcho_config = {
      baseUrl = "http://127.0.0.1:8001";
      enabled = true;
      pinUserPeer = true;
      recallMode = "hybrid";
      contextTokens = 2048;
      contextCadence = 1;
      dialecticCadence = 5;
      dialecticDepth = 1;
      dialecticReasoningLevel = "low";
      reasoningLevelCap = "low";
      writeFrequency = "async";
      sessionStrategy = "per-session";
    };
  });
  start = pkgs.writeShellScript "hermes-gateway-start" ''
    set -eu
    umask 077
    ${package.hermesVenv}/bin/python ${./_bootstrap.py} ${manifest}
    exec ${userHome.profileDirectory}/bin/hermes -p default gateway run
  '';
in {
  sops.secrets = {
    hermes_host_api_key = {owner = "augusto";};
    hermes_augusto_api_key = {owner = "augusto";};
    hermes_livia_api_key = {owner = "augusto";};
  };
  launchd.daemons.hermes-agent = {
    # launchd must not lend the host gateway ambient cloud credentials.
    command = "/usr/bin/env -i HOME=${home} HERMES_HOME=${root} PATH=${userHome.profileDirectory}/bin:${config.system.path}/bin:${pkgs.rtk}/bin:/usr/bin:/bin:/usr/sbin:/sbin ${start}";
    serviceConfig = {
      UserName = "augusto";
      RunAtLoad = true;
      KeepAlive = true;
      WorkingDirectory = home;
      StandardOutPath = "/var/log/hermes-agent.log";
      StandardErrorPath = "/var/log/hermes-agent.log";
    };
  };
  system.activationScripts.postActivation.text = ''
    install -d -m 0700 -o augusto -g staff ${root}
    touch /var/log/hermes-agent.log
    chown augusto:staff /var/log/hermes-agent.log
    chmod 0600 /var/log/hermes-agent.log
  '';
}

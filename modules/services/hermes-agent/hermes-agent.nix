{
  inputs,
  lib,
  ...
}: {
  # Share a current builder with Honcho; flake.lock owns the exact revision.
  flake-file.inputs.uv2nix = {
    url = "github:pyproject-nix/uv2nix";
    inputs.nixpkgs.follows = "hermes-agent/nixpkgs";
    inputs.pyproject-nix.follows = "hermes-agent/pyproject-nix";
  };
  flake-file.inputs.hermes-agent = {
    url = "github:NousResearch/hermes-agent";
    inputs.uv2nix.follows = "uv2nix";
  };
  flake-file.inputs.hermes-plugin-honcho = {
    url = "github:plastic-labs/honcho";
    flake = false;
  };
  den.aspects.hermes-agent.darwin = {
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
    localModel = {
      model = {
        provider = "custom";
        default = config.services.ollama.model;
        base_url = "http://127.0.0.1:11434/v1";
        context_length = 65536;
      };
      auxiliary.compression = {
        provider = "main";
        model = "";
      };
    };
    manifest = pkgs.writeText "hermes-profiles.json" (builtins.toJSON {
      host_config = localModel // {gateway.multiplex_profiles = true;};
      profile_config =
        localModel
        // {
          memory.provider = "honcho";
          mcp_servers = {
            context7 = {
              url = "https://mcp.context7.com/mcp";
              trust = "untrusted";
            };
            home_assistant = {
              url = "\${HERMES_HOME_ASSISTANT_MCP_URL}";
              headers.Authorization = "Bearer \${HERMES_HOME_ASSISTANT_TOKEN}";
              trust = "untrusted";
            };
          };
        };
      soul = ./SOUL.md;
      host_key = config.sops.secrets.hermes_host_api_key.path;
      profile_keys = {
        augusto = config.sops.secrets.hermes_augusto_api_key.path;
        livia = config.sops.secrets.hermes_livia_api_key.path;
      };
      mcp_secrets = {
        HERMES_HOME_ASSISTANT_MCP_URL = config.sops.secrets.hermes_home_assistant_mcp_url.path;
        HERMES_HOME_ASSISTANT_TOKEN = config.sops.secrets.hermes_home_assistant_token.path;
      };
      plugins = {
        honcho = "${inputs.hermes-plugin-honcho}/hermes-plugin-honcho";
        ponytail = "${inputs.ponytail}";
        # Upstream's adapter, version-matched to the binary: rewrites `terminal`
        # commands through `rtk rewrite`. Hermes's dangerous-command checks run
        # on the rewritten command.
        rtk-rewrite = "${pkgs.rtk.src}/hooks/hermes/rtk-rewrite";
      };
      enabled_plugins = ["rtk-rewrite" "ponytail"];
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
      exec ${lib.getExe package} gateway run
    '';
  in {
    environment.systemPackages = [package];
    sops.secrets = {
      hermes_host_api_key = {owner = "augusto";};
      hermes_augusto_api_key = {owner = "augusto";};
      hermes_livia_api_key = {owner = "augusto";};
      hermes_home_assistant_mcp_url = {owner = "augusto";};
      hermes_home_assistant_token = {owner = "augusto";};
    };
    launchd.daemons.hermes-agent = {
      # launchd must not lend the host gateway ambient cloud credentials.
      command = "/usr/bin/env -i HOME=${home} HERMES_HOME=${root} PATH=${pkgs.rtk}/bin:/usr/bin:/bin:/usr/sbin:/sbin ${start}";
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
  };
}

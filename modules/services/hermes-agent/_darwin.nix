# macmini: the household Hermes as a system LaunchDaemon.
{
  inputs,
  lib,
  models,
  fallbacks,
  disabledSkills,
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
    system = pkgs.stdenv.hostPlatform.system;
  };
  userHome = config.home-manager.users.augusto.home;
  wikiGate = import ./_wiki-gate.nix {
    inherit pkgs lib home;
    host = "macmini";
  };
  persons = ["augusto" "livia"];
  # Coding here should behave like the work profiles, so the household gets the same shared skills.
  sharedSkills = import ../../programs/agent-shared/_skills.nix {
    inherit lib pkgs;
    exclude = ["orchestrator"];
  };
  # Each person files sources into their own tree and hands the rest to its librarian.
  wikis = import ./_wikis.nix;
  wikiFor = person: lib.findFirst (wiki: wiki.writer == person) (throw "no wiki tree has writer ${person}") (builtins.attrValues wikis.trees.macmini);
  manifest = pkgs.writeText "hermes-household-profiles.json" (builtins.toJSON {
    host_config.gateway.multiplex_profiles = true;
    profile_configs = lib.genAttrs persons (name: {
      model = models.macmini.${name};
      auxiliary.compression = {
        provider = "main";
        model = "";
      };
      fallback_providers = fallbacks.macmini.${name};
      memory.provider = "hwiki";
      skills = {
        external_dirs = ["${sharedSkills.package}"];
        disabled = disabledSkills;
      };
      delegation = {
        backend = "profile_routes";
        backends.profile_routes.profiles = [{name = (wikiFor name).librarian;}];
      };
      mcp_servers = {
        context7 = {
          url = "https://mcp.context7.com/mcp";
          trust = "untrusted";
        };
      };
    });
    souls = lib.genAttrs persons (person:
      pkgs.writeText "${person}-SOUL.md" (builtins.readFile ./SOUL.md
        + "\n"
        + wikis.soul ./souls/_wiki.md (wikiFor person)
        + "\n"
        + lib.concatMapStringsSep "\n" builtins.readFile [
          ../../programs/agent-shared/style/caveman.md
          ../../programs/agent-shared/style/ponytail.md
        ]));
    host_key = config.sops.secrets.hermes_host_api_key.path;
    mcp_secrets = {};
    profile_env = lib.genAttrs persons (person: let
      wiki = wikiFor person;
    in {
      HASS_URL = "http://home.local:8123";
      OBSIDIAN_VAULT_PATH = "${home}/${wiki.vault}";
      WIKI_PATH = "${home}/${wiki.vault}/${wiki.tree}";
    });
    profile_keys = {
      augusto = config.sops.secrets.hermes_augusto_api_key.path;
      livia = config.sops.secrets.hermes_livia_api_key.path;
    };
    plugins = {
      hwiki = "${inputs.hermes-plugin-hwiki}";
      advanced-delegation = "${inputs.hermes-official-plugins}/advanced-delegation";
      homeassistant = "${inputs.hermes-official-plugins}/homeassistant";
      office-3d = "${inputs.hermes-plugin-office-3d}";
      # Upstream's adapter, version-matched to the binary: rewrites `terminal`
      # commands through `rtk rewrite`. Hermes's dangerous-command checks run
      # on the rewritten command.
      rtk-rewrite = "${pkgs.rtk.src}/hooks/hermes/rtk-rewrite";
      wiki-gate = "${wikiGate}";
      kanban-transcripts = "${import ./_kanban-transcripts.nix {inherit lib;}}";
    };
    enabled_plugins = ["rtk-rewrite" "advanced-delegation" "homeassistant" "office-3d" "wiki-gate" "kanban-transcripts"];
    # Per profile: hwiki's env overrides are process-wide, and one gateway serves both people.
    hwiki = lib.genAttrs persons (person: let
      wiki = wikiFor person;
    in {
      wiki_path = "${home}/${wiki.vault}";
      memory_dir = "${wiki.tree}/memory";
      untrusted_dirs = lib.concatMap (tree: ["${tree}/raw" "${tree}/review"]) (wikis.treesIn wiki.vault);
      demote_paths = ["log.md" "${wiki.tree}/memory/builtin-mirror.md"];
    });
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

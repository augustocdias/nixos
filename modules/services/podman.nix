{den, ...}: {
  den.aspects.podman = {
    nixos = {pkgs, ...}: {
      virtualisation.podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
      };
      virtualisation.containers.containersConf.settings.containers.oom_score_adj = 200;

      environment.systemPackages = [pkgs.podman-compose];
      environment.variables.PODMAN_COMPOSE_WARNING_LOGS = "false";
    };
  };
}

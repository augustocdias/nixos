# macmini: the Hermes gateway as a system LaunchDaemon. Profiles, bootstrap and the hermes wrapper
# come from _work.nix through Home Manager, like on the laptop.
{
  config,
  pkgs,
  ...
}: let
  home = "/Users/augusto";
  root = "${home}/.hermes";
  userHome = config.home-manager.users.augusto.home;
in {
  # API keys of the loopback listener: augusto's serves the root profile, livia's her profile.
  sops.secrets = {
    hermes_augusto_api_key = {owner = "augusto";};
    hermes_livia_api_key = {owner = "augusto";};
  };
  launchd.daemons.hermes-agent = {
    # launchd must not lend the host gateway ambient cloud credentials.
    command = "/usr/bin/env -i HOME=${home} HERMES_HOME=${root} PATH=${userHome.profileDirectory}/bin:${config.system.path}/bin:${pkgs.rtk}/bin:/usr/bin:/bin:/usr/sbin:/sbin ${userHome.profileDirectory}/bin/hermes -p default gateway run";
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

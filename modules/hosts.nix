{den, ...}: {
  den.hosts.x86_64-linux.laptop = {
    hostName = "nixos";
    aspect = den.aspects.laptop;
    users.augusto.aspect = den.aspects.user-linux;
  };

  den.hosts.aarch64-darwin.macmini = {
    hostName = "macmini";
    aspect = den.aspects.macmini;
    users.augusto.aspect = den.aspects.user-macos;
  };

  den.hosts.aarch64-linux.raspi = {
    hostName = "home";
    aspect = den.aspects.raspi;
  };

  den.hosts.x86_64-linux.vps-hermes = {
    hostName = "vps-hermes";
    aspect = den.aspects.vps-hermes;
    users.augusto.aspect = den.aspects.user-server;
    users.hermes.aspect = den.aspects.user-hermes;
  };
}

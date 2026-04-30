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
}

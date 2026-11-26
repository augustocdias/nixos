{inputs, ...}: {
  den.aspects.server-base = {
    nixos = {
      imports = [inputs.sops-nix.nixosModules.sops];

      # One age key per server decrypts both system and Home Manager secrets; the service user owns it.
      sops.age.keyFile = "/var/lib/sops-nix/key.txt";

      services.openssh = {
        enable = true;
        openFirewall = true;
        authorizedKeysInHomedir = false;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
          # Replaces a stale forwarded gpg-agent socket on reconnect.
          StreamLocalBindUnlink = "yes";
        };
      };
      networking.firewall.enable = true;

      nix.settings.trusted-users = ["root" "augusto"];
      security.sudo.wheelNeedsPassword = false;
      users.mutableUsers = false;
      users.users.augusto = {
        isNormalUser = true;
        uid = 1000;
        description = "Augusto";
        extraGroups = ["wheel"];
        # YubiKey login only; the agent key must never appear here.
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE8G/L1OaaDxw1pFQ8vYKVBSMnPZbty8AiUECQaHwNmW"
        ];
      };

      services.journald.settings.Journal.SystemMaxUse = "500M";

      time.timeZone = "Europe/Berlin";
      i18n = {
        defaultLocale = "en_US.UTF-8";
        extraLocaleSettings = {
          LC_TIME = "de_DE.UTF-8";
          LC_MONETARY = "de_DE.UTF-8";
          LC_PAPER = "de_DE.UTF-8";
          LC_MEASUREMENT = "de_DE.UTF-8";
        };
      };
      console.keyMap = "us";
    };
  };
}

{den, ...}: {
  # The admin user on a server: shell and editor, no services or secrets.
  den.aspects.user-server = {
    includes = with den.aspects; [
      git
      fish
      cli-tools
      neovim
      fonts
    ];

    homeManager = {
      # gpg talks to the forwarded YubiKey agent; the server runs no agent of its own.
      programs.gpg.enable = true;
      # The forwarded gpg-agent socket binds here, and sshd cannot create the directory.
      systemd.user.tmpfiles.rules = ["d %t/gnupg 0700 - - -"];
    };
  };
}

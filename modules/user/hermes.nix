{den, ...}: {
  # A server's unprivileged Hermes service user. Its secrets file holds only what Hermes needs, so a
  # worker that reads every file this user can reach still sees nothing else.
  den.aspects.user-hermes = {
    includes = with den.aspects; [
      git
      fish
      hermes
    ];

    homeManager = {
      pkgs,
      osConfig,
      ...
    }: {
      sops = {
        defaultSopsFile = ../hardware/vps-hermes/secrets.yaml;
        defaultSopsFormat = "yaml";
        age.keyFile = osConfig.sops.age.keyFile;
        secrets = {
          github_token = {};
          agent_ssh_key = {};
        };
      };
      # gh reads the agent token Hermes renders; claude logs in the Claude subscription once.
      home.packages = [pkgs.gh pkgs.claude-code];
    };
  };
}

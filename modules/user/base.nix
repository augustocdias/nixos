{den, ...}: {
  # Cross-platform user base aspect. Every aspect listed here must work on
  # BOTH nixos and darwin classes. Platform-specific user aspects
  # (`user-linux`, `user-macos`) include this and add their own extras.
  den.aspects.user-base = {
    includes = with den.aspects; [
      security
      secrets
      neovim
      git
      fish
      ghostty
      zellij
      starship
      bat
      yazi
      skim
      neovide
      opencode
      cli-tools
      fonts
      development
      applications
      update-system
    ];
  };
}

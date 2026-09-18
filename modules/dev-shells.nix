{inputs, ...}: {
  perSystem = {pkgs, ...}: let
    neovimPkg = inputs.self.nixosConfigurations.laptop.config.home-manager.users.augusto.programs.neovim.finalPackage;
  in {
    formatter = pkgs.alejandra;

    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        # nix language tooling
        alejandra
        deadnix
        statix
        nixd
        nix-tree

        # rebuild/diff helpers
        nix-output-monitor
        nvd

        # bumps the hand-pinned sources (packages.hass-*); see update-system
        nix-update

        # secrets (sops-nix)
        sops
        age
        ssh-to-age

        # the non-nix files this repo carries
        stylua
        selene
        yamllint
        actionlint
      ];

      shellHook = ''
        echo "nixos config dev shell"
        echo "  nix flake check          -- evaluate every host"
        echo "  nix fmt                  -- alejandra"
        echo "  statix check . && deadnix -- lint"
        echo "  nix run .#write-flake    -- regenerate flake.nix"
        echo "  nix-update -f . -F <pkg> -- bump a hand-pinned source (packages.hass-*)"
      '';
    };

    devShells.nvim-dev = pkgs.mkShell {
      packages = [
        (pkgs.writeShellScriptBin "nvim" ''
          PLUGIN_DIR="''${NVIM_DEV_PLUGIN:-$PWD}"
          exec ${neovimPkg}/bin/nvim --cmd "lua vim.opt.rtp:prepend('$PLUGIN_DIR')" "$@"
        '')
      ];

      shellHook = ''
        echo "Neovim dev shell active"
        echo "Plugin dir: ''${NVIM_DEV_PLUGIN:-$PWD}"
      '';
    };
  };
}

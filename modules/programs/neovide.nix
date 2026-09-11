{den, ...}: {
  den.aspects.neovide = {
    homeManager = {
      programs.neovide = {
        enable = true;

        settings.font = {
          normal = [
            {
              family = "MonaspiceNe Nerd Font";
              style = "Retina";
            }
            {family = "codicon";}
          ];
          italic = {
            family = "MonaspiceRn Nerd Font";
            style = "italic";
          };
          size = 12;
          edging = "subpixelantialias";
        };
      };
    };
  };
}

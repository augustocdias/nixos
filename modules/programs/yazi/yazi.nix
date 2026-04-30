{den, ...}: {
  den.aspects.yazi = {
    homeManager = {
      pkgs,
      lib,
      ...
    }: let
      isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

      clipboardPluginName =
        if isDarwin
        then "clipboard"
        else "wl-clipboard";
    in {
      programs.yazi = {
        enable = true;
        enableFishIntegration = true;
        enableBashIntegration = true;
        initLua = ./init.lua;
        shellWrapperName = "y";
        settings = {
          theme = lib.importTOML ./theme.toml;
          mgr = {
            show_symlink = true;
            show_hidden = true;
          };
          keymap.mgr.prepend_keymap = [
            {
              on = "<C-y>";
              run = ["plugin ${clipboardPluginName}"];
              desc = "Copy file (or contents) to clipboard";
            }
            {
              on = "<C-d>";
              run = ["plugin diff"];
              desc = "Diff the selected with the hovered file";
            }
            {
              on = ["c" "m"];
              run = ["plugin chmod"];
              desc = "Chmod on selected files";
            }
            {
              on = ["c" "a" "a"];
              run = ["plugin compress"];
              desc = "Archive selected files";
            }
            {
              on = ["c" "a" "p"];
              run = ["plugin compress -p"];
              desc = "Archive selected files (password)";
            }
            {
              on = ["c" "a" "h"];
              run = ["plugin compress -ph"];
              desc = "Archive selected files (password+header)";
            }
            {
              on = ["c" "a" "l"];
              run = ["plugin compress -l"];
              desc = "Archive selected files (compression level)";
            }
            {
              on = ["c" "a" "u"];
              run = ["plugin compress -phl"];
              desc = "Archive selected files (password+header+level)";
            }
          ];
          plugin = {
            prepend_previewers = [
              {
                url = "*.csv";
                run = "rich-preview";
              }
              {
                url = "*.md";
                run = "rich-preview";
              }
              {
                url = "*.rst";
                run = "rich-preview";
              }
              {
                url = "*.ipynb";
                run = "rich-preview";
              }
              {
                url = "*.json";
                run = "rich-preview";
              }
            ];
            prepend_fetchers = [
              {
                id = "git";
                url = "*";
                run = "git";
              }
              {
                id = "git";
                url = "*/";
                run = "git";
              }
            ];
          };
        };
        plugins =
          {
            inherit
              (pkgs.yaziPlugins)
              git
              diff
              chmod
              compress
              rich-preview
              ;
          }
          // (
            if isDarwin
            then {inherit (pkgs.yaziPlugins) clipboard;}
            else {inherit (pkgs.yaziPlugins) wl-clipboard;}
          );
      };
    };
  };
}

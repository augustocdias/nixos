{den, ...}: {
  den.aspects.omniwm = {
    homeManager = {lib, ...}: let
      workspaceHotkeys = lib.concatMap (
        i: let
          slot = toString (i - 1);
          key = toString i;
        in [
          {
            id = "switchWorkspace.${slot}";
            binding = "Option+${key}";
          }
          {
            id = "moveToWorkspace.${slot}";
            binding = "Option+Shift+${key}";
          }
        ]
      ) (lib.range 1 9);

      mkFloat = idx: matchers:
        {
          id = "00000000-0000-4000-8000-${lib.fixedWidthString 12 "0" (toString idx)}";
          bundleId = "";
          layout = "float";
        }
        // matchers;
    in {
      programs.omniwm = {
        enable = true;

        launchd = {
          enable = true;
          keepAlive = true;
        };

        settings = {
          schemaVersion = 3;

          general = {
            defaultLayoutType = "dwindle";
            ipcEnabled = true;
            updateChecksEnabled = false;
          };

          gaps = {
            size = 8.0;
            outer = {
              left = 8.0;
              right = 8.0;
              top = 8.0;
              bottom = 8.0;
            };
          };

          hotkeys =
            [
              {
                id = "focus.left";
                binding = "Option+H";
              }
              {
                id = "focus.down";
                binding = "Option+J";
              }
              {
                id = "focus.up";
                binding = "Option+K";
              }
              {
                id = "focus.right";
                binding = "Option+L";
              }
              {
                id = "move.left";
                binding = "Option+Shift+H";
              }
              {
                id = "move.down";
                binding = "Option+Shift+J";
              }
              {
                id = "move.up";
                binding = "Option+Shift+K";
              }
              {
                id = "move.right";
                binding = "Option+Shift+L";
              }
              {
                id = "resizeShrink.horizontal";
                binding = "Control+Command+H";
              }
              {
                id = "resizeGrow.vertical";
                binding = "Control+Command+J";
              }
              {
                id = "resizeShrink.vertical";
                binding = "Control+Command+K";
              }
              {
                id = "resizeGrow.horizontal";
                binding = "Control+Command+L";
              }
              {
                id = "balanceSizes";
                binding = "Control+Command+0";
              }
              {
                id = "toggleFullscreen";
                binding = "Option+F";
              }
              {
                id = "toggleFocusedWindowFloating";
                binding = "Option+Shift+F";
              }
              {
                id = "swapSplit";
                binding = "Option+E";
              }
              {
                id = "toggleSplit";
                binding = "Option+T";
              }
              {
                id = "toggleWorkspaceLayout";
                binding = "Control+Command+R";
              }
              {
                id = "toggleQuakeTerminal";
                binding = "Option+Return";
              }
            ]
            ++ workspaceHotkeys;

          appRules = lib.imap1 mkFloat [
            {appNameSubstring = "System Information";}
            {appNameSubstring = "Calculator";}
            {
              appNameSubstring = "Finder";
              titleRegex = "Co(py|nnect)|Move|Info|Pref";
            }
            {appNameSubstring = "1Password";}
            {titleSubstring = "Preferences";}
            {appNameSubstring = "System Settings";}
            {appNameSubstring = "Activity Monitor";}
            {appNameSubstring = "Maps";}
            {appNameSubstring = "Music";}
            {appNameSubstring = "Notes";}
            {appNameSubstring = "Messages";}
            {appNameSubstring = "WhatsApp";}
            {appNameSubstring = "QuickTime Player";}
            {
              appNameSubstring = "Safari";
              titleSubstring = "Advanced";
            }
            {
              appNameSubstring = "Godot";
              titleRegex = "^(?!$)(?!.*Godot Engine$).*";
            }
          ];
        };
      };
    };
  };
}

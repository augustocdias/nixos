{den, ...}: {
  den.aspects.home-assistant = {
    nixos = {pkgs, ...}: let
      cards = pkgs.callPackage ./_lovelace-modules.nix {};
      extraThemes = pkgs.callPackage ./_themes.nix {};
      berlin-transport = pkgs.callPackage ./_berlin-transport.nix {
        inherit (pkgs.home-assistant.python3Packages) async-timeout;
      };
      ha-mcp-tools = pkgs.callPackage ./_ha-mcp.nix {
        python3Packages = pkgs.home-assistant.python3Packages;
      };
    in {
      services.home-assistant = {
        enable = true;

        extraComponents = import ./_components.nix;

        extraPackages = ps: with ps; [zlib-ng isal];

        customComponents = [
          berlin-transport
          ha-mcp-tools
        ];

        customLovelaceModules =
          (with pkgs.home-assistant-custom-lovelace-modules; [
            advanced-camera-card
            apexcharts-card
            atomic-calendar-revive
            auto-entities
            battery-state-card
            bubble-card
            button-card
            card-mod
            clock-weather-card
            decluttering-card
            fold-entity-row
            mini-graph-card
            multiple-entity-row
            mushroom
            navbar-card
            sankey-chart
            swipe-navigation
            template-entity-row
            vacuum-card
            weather-card
          ])
          ++ (with cards; [
            berlin-transport-card
            birthday-reminder-card
            hui-element
            more-info-card
            slider-entity-row
            status-card
          ]);

        themes =
          [pkgs.home-assistant-themes.catppuccin]
          ++ (with extraThemes; [
            frosted-glass-themes
            ios-themes
            macos-theme
          ]);

        config = {
          default_config = {};
          bluetooth = {};

          tts = [{platform = "google_translate";}];

          recorder.exclude = {
            domains = [
              "button"
              "image"
              "notify"
              "update"
            ];
            entities = [
              "sensor.date"
              "sensor.date_time"
              "sensor.date_time_iso"
              "sensor.processor_use_percent"
              "sensor.time"
            ];
            entity_globs = [
              "sensor.load_*"
              "sensor.memory_*"
              "sensor.swap_*"
              "sensor.system_monitor_network_*"
              "sensor.system_monitor_packets_*"
            ];
          };

          group = "!include groups.yaml";
          automation = "!include automations.yaml";
          script = "!include scripts.yaml";
          scene = "!include scenes.yaml";
          template = "!include templates.yaml";
        };
      };

      services.matterjs-server = {
        enable = true;
        extraArgs = ["--ble-proxy"];
      };
    };
  };
}

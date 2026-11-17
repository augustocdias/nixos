{den, ...}: {
  den.aspects.obsidian = {
    homeManager = {
      config,
      pkgs,
      lib,
      ...
    }: let
      # The laptop writes the work tree and the macmini the home tree.
      tree =
        if pkgs.stdenv.hostPlatform.isDarwin
        then "home"
        else "work";

      # Release assets of a community plugin or theme. manifestId spares the
      # Home Manager module from reading manifest.json at evaluation time.
      mkRelease = manifestId: repo: version: hashes:
        pkgs.runCommand "obsidian-${manifestId}-${version}" {passthru = {inherit manifestId;};} ''
          mkdir $out
          ${lib.concatStrings (lib.mapAttrsToList (file: hash: ''
              cp ${pkgs.fetchurl {
                url = "https://github.com/${repo}/releases/download/${version}/${file}";
                inherit hash;
              }} $out/${file}
            '')
            hashes)}
          # Themes have no id, only a name.
          ${lib.getExe pkgs.jq} -e '(.id // .name) == "${manifestId}"' $out/manifest.json
        '';

      mediaExtended = mkRelease "media-extended" "aidenlx/media-extended" "4.2.9" {
        "main.js" = "sha256-x0pr0qitgb7GjpHFhilqGm7RXklAlgW83fnblw4Ra2w=";
        "manifest.json" = "sha256-lyPv0Noc4/gfoI+GKdF544ROO9ImMNSzV5pOxvWC5kM=";
        "styles.css" = "sha256-tx0XFnWLhud3K6D4H4adNGbLLuZasAJwQ66CxAoh1Iw=";
      };
      # Media Extended loads its main daemon, an Electron main-process module with a bundled
      # browser extension, from Obsidian's userData folder and offers to download it when the
      # file is missing. The plugin manifest names the daemon version it accepts.
      mxDaemonVersion = "1.0.3";
      mxDaemon = pkgs.runCommand "mx-main-daemon-${mxDaemonVersion}.asar" {} ''
        ${lib.getExe pkgs.jq} -e '.versions."@mx/main-daemon" == "${mxDaemonVersion}"' ${mediaExtended}/manifest.json
        cp ${pkgs.fetchurl {
          url = "https://github.com/aidenlx/media-extended/releases/download/main-daemon-${mxDaemonVersion}/mx-main-daemon-${mxDaemonVersion}.asar";
          hash = "sha256-Ul3HmaPRjB5EOJP8Y9ZJc3vcOvVTK3CTAFj498Q9PUQ=";
        }} $out
      '';
      # Same folder the Home Manager obsidian module merges obsidian.json into.
      obsidianUserData =
        if pkgs.stdenv.hostPlatform.isDarwin
        then "${config.home.homeDirectory}/Library/Application Support/obsidian"
        else "${config.xdg.configHome}/obsidian";

      # Graph colors are Catppuccin Mocha as RGB integers.
      color = rgb: {
        a = 1;
        inherit rgb;
      };

      vault = "obsidian-vault";

      # Web Clipper templates live only in browser sync storage, so this renders the clipper's
      # "Import all settings" file (obsidian-clipper 1.7.1, src/utils/import-export.ts):
      # the raw storage keys, with templates as plain objects that the import compresses.
      clipperTemplate = treeName: kind: triggers: {
        id = "${treeName}-${kind}";
        name = "${lib.toUpper (lib.substring 0 1 treeName)}${lib.substring 1 (-1) treeName} ${kind}";
        behavior = "create";
        inherit vault;
        path = "${treeName}/raw/${kind}s";
        noteNameFormat = ''{{date|date:"YYYY-MM-DD"}}-{{title|safe_name|kebab}}'';
        noteContentFormat = "{{content}}";
        context = "";
        inherit triggers;
        # Raw frontmatter from souls/_wiki.md; the librarian adds ingested and sha256.
        properties =
          map (name: {
            inherit name;
            value = "{{${
              if name == "source_url"
              then "url"
              else name
            }}}";
            type = "text";
          }) ["source_url" "title" "author"]
          ++ [
            {
              name = "published";
              value = "{{published}}";
              type = "date";
            }
            {
              name = "clipped";
              value = "{{date}}";
              type = "date";
            }
            {
              name = "type";
              value = kind;
              type = "text";
            }
            {
              name = "unprocessed";
              value = "true";
              type = "checkbox";
            }
          ];
      };
      youtube = ["https://www.youtube.com/watch" "https://m.youtube.com/watch" "https://youtu.be/"];
      # The host's own tree comes first: the first template is the default and wins shared triggers.
      clipperTemplates = lib.concatMap (t: [(clipperTemplate t "article" []) (clipperTemplate t "video" youtube)]) [
        tree
        (
          if tree == "work"
          then "home"
          else "work"
        )
      ];
    in {
      xdg.configFile."obsidian-clipper/settings.json".text = builtins.toJSON ({
          vaults = [vault];
          template_list = map (t: t.id) clipperTemplates;
          # Without these types the clipper writes dates and the flag as quoted text.
          property_types = map (p: {inherit (p) name type;}) (lib.head clipperTemplates).properties;
        }
        // lib.listToAttrs (map (t: lib.nameValuePair "template_${t.id}" t) clipperTemplates));

      # A real file, not a store symlink: the daemon extracts its extension from beside itself,
      # as it does after the plugin's own install.
      home.activation.mediaExtendedDaemon = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run install -D -m 644 ${mxDaemon} ${lib.escapeShellArg "${obsidianUserData}/mx-main-daemon-${mxDaemonVersion}.asar"}
      '';

      programs.obsidian = {
        enable = true;
        vaults.${vault}.settings = {
          app = {
            useMarkdownLinks = false;
            newLinkFormat = "shortest";
            # A rename in the UI must never rewrite gold pages.
            alwaysUpdateLinks = false;
            vimMode = true;
            readableLineLength = true;
            showLineNumber = true;
            trashOption = "local";
            userIgnoreFilters = [
              "work/review/applied/"
              "home/review/applied/"
            ];
          };

          appearance.theme = "obsidian";

          themes = [
            (mkRelease "Catppuccin" "catppuccin/obsidian" "0.4.52" {
              "manifest.json" = "sha256-vjbS8zhQZ1NPowSQZ7GXqKjZBfpk5ypIOHvRWQw4JHk=";
              "theme.css" = "sha256-bBMwcArgB39cedlQqQF5pC53eHIp3hJ25cvloEjlcu0=";
            })
          ];

          corePlugins = [
            "file-explorer"
            "global-search"
            "switcher"
            {
              name = "graph";
              # First match wins, so contested pages and the review folder come before the gold folders.
              settings.colorGroups = [
                {
                  query = "[contested:true]";
                  color = color 15961000; # red
                }
                {
                  query = "path:/review/";
                  color = color 16376495; # yellow
                }
                {
                  query = "path:/entities/";
                  color = color 9024762; # blue
                }
                {
                  query = "path:/concepts/";
                  color = color 13346551; # mauve
                }
                {
                  query = "path:/comparisons/";
                  color = color 10937249; # green
                }
                {
                  query = "path:/queries/";
                  color = color 9757397; # teal
                }
              ];
            }
            "backlink"
            "outgoing-link"
            "tag-pane"
            "properties"
            "page-preview"
            "outline"
            "bases"
            "bookmarks"
            "command-palette"
            "file-recovery"
          ];

          communityPlugins = [
            {
              pkg = mkRelease "obsidian-git" "vinzent03/obsidian-git" "2.43.0" {
                "main.js" = "sha256-WL6wmBh1xnL8gzUOOx8g22yh3zyiBHol9JGQseMeJEM=";
                "manifest.json" = "sha256-TzRQ8yAfAuLh6L8qhzC/yDfPQqJduZG7XZMFbRcJOVE=";
                "styles.css" = "sha256-kq6A0mAOW8dkPdq8qjfYiOEul2Pv/2PcqVzJSkQhB4E=";
              };
              settings = {
                autoSaveInterval = 0;
                autoPushInterval = 0;
                autoPullOnBoot = true;
                autoPullInterval = 10;
                syncMethod = "rebase";
                pullBeforePush = true;
                # The sync audit skips commits with this prefix (wiki-gate manual_prefix).
                commitMessage = "manual: vault edit {{date}}";
                autoCommitMessage = "manual: vault edit {{date}}";
              };
            }
            # Omnisearch keeps a writable data.json for its cache, so it gets no settings.
            (mkRelease "omnisearch" "scambier/obsidian-omnisearch" "1.32.0" {
              "main.js" = "sha256-JzTWTU5IN3P3kh/QcQBzUZVF9yyJ9yyqnpaz6useleo=";
              "manifest.json" = "sha256-Dkj4envOImw5h4J2D1LAuJKqo5bNWnYvSKIAx+d5Ah8=";
              "styles.css" = "sha256-xqVrGhj/hn8S67s6E5BgoklwQoHhtEkAP/SHlpYhouY=";
            })
            {
              pkg = mkRelease "homepage" "mirnovov/obsidian-homepage" "4.6.0" {
                "main.js" = "sha256-nGxesJFKHVB645Hdue8F7v/NVrcw7WZ5p3VccvyrovY=";
                "manifest.json" = "sha256-UZeDxakT1ONZGxzJiW2EvI1eSiEM8DLZL6vgzq9tcxw=";
                "styles.css" = "sha256-vzRt70bmYmRGxUmD9+bOR3W4SwEVnNBGMB6b5cNAdYk=";
              };
              settings = {
                version = 5;
                separateMobile = false;
                homepages."Main Homepage" = {
                  value = "${tree}/review/inbox.base";
                  kind = "File";
                  openOnStartup = true;
                  openMode = "Replace all open notes";
                };
              };
            }
            (mkRelease "obsidian-front-matter-title-plugin" "snezhig/obsidian-front-matter-title" "4.3.0" {
              "main.js" = "sha256-IF92o/s6JSduoA1QfA1K9HIVJssbkKzDJ0KJGvV+Ol0=";
              "manifest.json" = "sha256-Z2R+YgKlMx+OIx4GcFBOfly6jNCXREtCUTmQ6SElXOU=";
            })
            {
              pkg = mkRelease "obsidian-style-settings" "obsidian-community/obsidian-style-settings" "1.0.9" {
                "main.js" = "sha256-GCirqs2rTFV4twWmJcWFswUS+O+tTHz8WhjnDMNVdGg=";
                "manifest.json" = "sha256-nP/cIM8qoTVIIOAFC2lLD5tXZEbj1dRKNq6LAYflv7g=";
                "styles.css" = "sha256-7nk30r5QZTqJzLMK5fBXKyNQfVt/EyjQBScaNjB1v9g=";
              };
              settings."catppuccin-theme-settings@@catppuccin-theme-dark" = "ctp-mocha";
            }
            (mkRelease "breadcrumbs" "michaelpporter/breadcrumbs" "4.22.3" {
              "main.js" = "sha256-befQKuw7pPsHJ19LbFAUcFM3y4VWJJ0Bx1zz5GxgzZ0=";
              "manifest.json" = "sha256-uTsprHm51ijCWigyeYgM4cQc7Pr8fvoX7k5XI9bP5Q8=";
              "styles.css" = "sha256-pmXvPVkcDAXbs1YA+80sVU1/FJFuKF3dHzw9GjCi/QU=";
            })
            # Media Extended records the last-seen release in data.json on start, so it gets no settings.
            mediaExtended
          ];
        };
      };
    };
  };
}

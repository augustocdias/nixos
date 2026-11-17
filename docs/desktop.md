# Desktop reference

Linux desktop wiring lives in `modules/desktop/hyprland.nix` and `modules/desktop/dms.nix`; macOS window management lives in `modules/desktop/omniwm.nix`.

## Hyprland (laptop)

### Lua config

Hyprland 0.56 parses only Lua, so any hyprlang `.conf` is a syntax error. Home Manager writes `~/.config/hypr/hyprland.lua` because `wayland.windowManager.hyprland.configType` defaults to `"lua"` for `home.stateVersion` 26.05 and later. A config error drops Hyprland into emergency mode, where no configured binds exist (only `SUPER+Q` terminal, `SUPER+R` run, `SUPER+M` exit).

How `settings` renders:

- Each attribute becomes `hl.<name>(...)`, one call per list element.
- `_args` renders a multi-argument call, and `_var` renders a `local`.
- `lib.generators.mkLuaInline` emits raw Lua. Dispatchers (`hl.dsp.*`) are function calls, so they need it.
- Option sections go under `settings.config`, which renders `hl.config({...})`. There is no `hl.general`.

Look up `hl.*` names in the LuaLS stubs at `<hyprland>/share/hypr/stubs/hl.meta.lua`; Home Manager points `~/.config/hypr/.luarc.json` at them. To validate a change, mock `hl` from the stubs in a scratch directory and execute the generated file to catch unknown calls.

### Bindings

- `SUPER` is the modifier, interpolated from the Nix `mod` variable. Key strings look like `"SUPER + SHIFT + K"`.
- Directional bindings use hjkl only.
- `binde` is `{ repeating = true }`. Mouse binds are the `hl.dsp.window.drag()` and `hl.dsp.window.resize()` dispatchers; Hyprland has no `mouse` bind option, despite the upstream example.
- The resize submap is `settings.define_submap`.

### Window rules and autostart

Rules match Wayland app-ids with RE2 full match, case-sensitively. Native-Wayland Electron apps report lowercase ids, so their rules use `(?i)`. Check real classes with `hyprctl -j clients | jq '.[].class'`. A class rule captures every window of that app.

Autostart entries run together through `/bin/sh -c`, so the active workspace races window mapping. Place autostarted apps with `window_rule` and `workspace = "N silent"`, not with a `hyprctl dispatch workspace N &&` prefix.

### Session

The session is uwsm-managed, so `wayland.windowManager.hyprland.systemd.enable` must stay explicitly `false`. It defaults to `true`, and removing the line re-enables it. Home Manager's start hook would then stop `hyprland-session.target`, which propagates through uwsm's `wayland-session@` target and tears the session down: an endless greeter loop. uwsm owns `graphical-session.target` and both activation environments, and DMS hangs off that target. See <https://wiki.hypr.land/Useful-Utilities/Systemd-start/>.

Always pick the **Hyprland (uwsm-managed)** session. The plain "Hyprland" entry still exists and starts without DMS.

## DankMaterialShell (DMS)

DMS is the whole desktop shell, built on Quickshell: bar, launcher, lock screen, notifications, clipboard, screenshots, recording, idle and power management, tray, and plugins. Add these features through DMS settings in `dms.nix`, not separate tools.

DMS runs as a systemd user service. Hyprland binds call it through `dms ipc call <target> <method>` (for example `dms ipc call launcher toggle`) and `dms screenshot`. The binds in `hyprland.nix` show the targets in use.

Flake inputs: `dms` (Home Manager module), `dms-plugins` (plugin registry), `dank-greeter`, and `dank-pinentry`.

### Calendar daemon detection

Dank Calendar checks its daemon socket by launching `test -S` directly. A running daemon can appear offline if another package shadows the standard `test` executable. `modules/packages/development.nix` removes the unrelated test runner shipped by `gh-stack` to prevent this collision. After activating that package change, restart `dcal.service` because the UI probes the socket only once at startup.

### Greeter

The greeter comes from the `dank-greeter` flake (`programs.dms-greeter`), with greetd and Hyprland as its compositor. It copies the user's DMS theme, wallpaper, and settings into `/var/lib/dms-greeter` via `configHome` before greetd starts.

`programs.dms-greeter.compositor.customConfig` must be Lua. dms-greeter chooses its appended launch snippet by sniffing the custom config for `hl.` (or a `.lua` suffix). Without a match it appends a hyprlang `exec-once` line, and the greeter dies before Quickshell starts.

### Pinentry

`security.nix` sets the gpg-agent pinentry: `dank-pinentry` on Linux and `pinentry_mac` on Darwin. dank-pinentry prompts in the terminal when one is usable, otherwise inside DankBar through the `dankbarPinentry` plugin, which is hidden when idle.

<a id="window-management--omniwm"></a>

## Window management with OmniWM (macmini)

The `omniwm` aspect is Home Manager (`programs.omniwm`) and is included by `user-macos`. It keeps SIP enabled; OmniWM is signed and notarized.

- Hotkeys are built in. Each hotkey id holds exactly one binding, so assigning a new key to an id moves it rather than adding an alias.
- Bindings use `Option` as the modifier and hjkl for direction.
- OmniWM has no launch command and no close-window command. `Option+Return` is `toggleQuakeTerminal` (Ghostty), 1Password opens from a Raycast hotkey, and `Cmd+W` closes windows.
- Float rules may set `bundleId = ""` when another matcher is set. Each rule needs an explicit `id` UUID; `mkFloat` generates them.
- `settings.toml` is Nix-owned, and the GUI fights it. OmniWM rewrites the file from its Settings window and on version migration; the Home Manager module relinks it with `force = true` on every switch. Mirror any GUI change worth keeping into Nix. Add hotkey ids introduced by an upgrade by hand.
- OmniWM requires macOS 26+, Accessibility and Input Monitoring permissions, and "Displays have separate Spaces" on. It pauses until that setting is on.

## Obsidian (laptop and macmini)

`modules/programs/obsidian.nix` (aspect `obsidian`, in `user-base`) configures Augusto's wiki vault, `~/obsidian-vault`, through Home Manager `programs.obsidian`. The file owns the settings, core and community plugins, theme and graph colors. Community plugins and the Catppuccin theme are release assets pinned by hash. The wiki itself is described in [Coding agents](coding-agents.md#llm-wiki).

- **Host tree.** The laptop opens the `work` tree's review inbox on start and the macmini the `home` tree's. The sync job creates `<tree>/review/inbox.base`; until it exists the homepage has nothing to open.
- **Rename-safe.** Link updates on rename are off, so a rename in the UI never rewrites gold pages.
- **Omnisearch** gets no Nix settings, because it keeps its cache in its own writable `data.json`. Media Extended gets none either: it records the last-seen release there on start.
- **Media Extended daemon.** The plugin loads `mx-main-daemon-<version>.asar` from Obsidian's userData folder (`~/.config/obsidian`, or `~/Library/Application Support/obsidian` on Darwin) into Obsidian's Electron main process. No separate process or service runs. When the file is missing it opens a setup dialog that downloads it from GitHub. Activation copies the pinned file there instead, as a real file, because the daemon extracts its bundled browser extension from its own location. The build fails if the plugin manifest's `versions."@mx/main-daemon"` stops matching the pinned daemon, so bump both together. After a bump the plugin deletes the older daemon files once the new one initializes.
- **obsidian-git and the checkout.** obsidian-git pulls but never commits or pushes on its own, and activation creates `.obsidian/` inside the vault, so clone it before the first switch. [Coding agents](coding-agents.md#llm-wiki) explains both under manual edits and vault checkout.

### Web Clipper

The laptop's Firefox gets the clipper from `modules/programs/firefox/extensions.json`, updated by `update-firefox`. The macmini's Safari gets it as a Mac App Store app in `modules/hardware/macmini/macmini.nix`. Sign the Apple ID in to the App Store before that switch, or activation fails.

The clipper keeps its templates in extension sync storage and never reads managed storage, so neither Firefox policies nor Home Manager extension settings can set them. `obsidian.nix` renders the clipper's import-all-settings file at `~/.config/obsidian-clipper/settings.json`. Import it once in each browser, and again after changing the templates. The host's own tree comes first in the template list: the first template is the default and wins shared triggers, such as YouTube URLs. Clips land in the tree's `raw/` folder with the frontmatter the librarian expects.

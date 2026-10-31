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

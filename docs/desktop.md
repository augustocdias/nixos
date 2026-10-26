# Desktop reference

Read before changing compositors, greeters, window managers, keyboard bindings, desktop sessions, or shell configuration. Source files remain authoritative for current values.

## Desktop Environment

### Hyprland

Wayland tiling compositor with:

- **Config format: Lua, not hyprlang.** Hyprland 0.56 deleted the hyprlang parser — `Config::initConfigManager` constructs `Lua::CConfigManager` on both branches and `typeToString` only knows `CONFIG_LUA`, so *any* `.conf` is now a Lua syntax error. `wayland.windowManager.hyprland.configType = "lua"` makes home-manager write `~/.config/hypr/hyprland.lua`. A config error trips Hyprland's **emergency mode** (no binds registered; only `SUPER+Q` terminal, `SUPER+R` `hyprland-run`, `SUPER+M` exit).
- **How `settings` maps to Lua**: each attribute becomes `hl.<name>(...)`, one call per list element. `_args` renders a multi-argument call, `_var` a `local`, and `lib.generators.mkLuaInline` a raw Lua expression (needed for `hl.dsp.*`, which are function calls, not data). Note the whole tree moves under `hl.config({...})` — there is no `hl.general`, so a bare `configType` flip yields syntactically valid Lua that dies on a nil call.
- **Session is uwsm-managed, so `wayland.windowManager.hyprland.systemd.enable` must be explicitly `false`.** It defaults to `true`, and merely deleting the option re-enables it. HM's start hook runs `systemctl --user stop hyprland-session.target`, whose `PropagatesStopTo=graphical-session.target` is `BindsTo`'d by uwsm's `wayland-session@` target → the compositor is stopped, exits 0, and its `OnSuccess=wayland-session-shutdown.target` (`replace-irreversibly`) tears the session down — an endless greeter loop, while the plain non-uwsm session entry still works. uwsm owns `graphical-session.target` plus both the systemd and D-Bus activation environments, and `dms.service`/`wl-clip-persist` hang off `graphical-session.target`, so nothing is lost. Documented at <https://wiki.hypr.land/Useful-Utilities/Systemd-start/>. Consequence: the plain "Hyprland" session entry (which the hyprland package puts in the system path regardless) starts without DMS — always pick **Hyprland (uwsm-managed)**.
- **Window rules match Wayland app-ids via RE2 `FullMatch`, case-sensitively.** Native-Wayland Electron apps report lowercase (`slack`, `cider`, not `Slack`/`Cider`), so those rules use `(?i)` inline flags. Check real classes with `hyprctl -j clients | jq '.[].class'` rather than trusting the old hyprlang rules. `workspace = "N silent"` keeps working as one string.
- **Don't prefix autostart entries with `hyprctl dispatch workspace N &&`.** `hl.exec_cmd` does run via `/bin/sh -c`, so the `&&` is fine, but every entry is spawned at once and the active workspace races the window actually mapping. Place windows with `window_rule` instead — and note a class rule captures *every* window of that app, which is why firefox has none.
- **API reference**: Hyprland ships LuaLS stubs at `<hyprland>/share/hypr/stubs/hl.meta.lua` (home-manager points `.luarc.json` at them). Use those rather than guessing dispatcher names; `/tmp` scratch validation can mock `hl` from the stubs and execute the generated file to catch unknown `hl.*` calls.
- **Layout**: dwindle (default) + scrolling workspace (plugin)
- **Monitors**: eDP-1 (laptop, workspaces 1-5) + DP-1 (external, workspaces 6-10)
- **Keybindings**: `SUPER` as main modifier, written as `"SUPER + SHIFT + K"` key strings. All directional bindings use hjkl (no arrow keys). `binde` is `{ repeating = true }`; `bindm` is just the mouse dispatcher (`hl.dsp.window.drag()` / `hl.dsp.window.resize()`) — there is no `mouse` bind option despite the upstream example using one. The resize submap is `settings.define_submap`.
- **Auto-start**: Slack, Thunderbird, ZapFast (WhatsApp), Firefox, Ghostty, DataGrip (assigned to specific workspaces). The Ghostty window starts a plain shell; the multiplexer is launched by hand.
- **Window rules**: Float dialogs, PiP, file pickers. Size constraints for various apps.

### DankMaterialShell (DMS)

DMS is a **comprehensive Wayland desktop shell** built on [Quickshell](https://git.outfoxxed.me/quickshell/quickshell) (Qt/QML). It replaces the entire typical Wayland desktop toolkit stack:

| DMS replaces      | Traditional tool           |
| ----------------- | -------------------------- |
| Top bar/panel     | Waybar, Polybar            |
| App launcher      | Rofi, Wofi, Fuzzel         |
| Lock screen       | Swaylock, Hyprlock         |
| Login greeter     | greetd + tuigreet/gtkgreet |
| Notifications     | dunst, mako                |
| Clipboard manager | cliphist, clipman          |
| Screenshot tool   | grim + slurp               |
| Screen recorder   | wf-recorder                |
| Idle management   | swayidle, hypridle         |
| Power menu        | wlogout                    |
| System tray       | (built-in)                 |

#### Architecture

DMS runs as a **systemd user service** and communicates with Hyprland through:

- **IPC**: `dms ipc call <target> <method>` (e.g., `dms ipc call launcher toggle`)
- **CLI**: `dms screenshot [full] [--no-file] [--no-clipboard] [-d <dir>]`
- **Hyprland keybindings** that invoke `dms` commands (SUPER+SPACE for launcher, SUPER+SHIFT+L for lock, etc.)

#### Key IPC commands

| Command                                      | Action           |
| -------------------------------------------- | ---------------- |
| `dms ipc call launcher toggle`               | App launcher     |
| `dms ipc call powermenu toggle`              | Power menu       |
| `dms ipc call lock lock`                     | Lock screen      |
| `dms ipc call plugins toggle aiAssistant`    | AI assistant     |
| `dms ipc call screenRecorder startRecording` | Screen recording |
| `dms ipc call screenRecorder stopRecording`  | Stop recording   |
| `dms ipc call mpris playPause/previous/next` | Media control    |

#### Features configured in this repo

- **Bar**: top position, 50% transparency, Catppuccin theme, widgets: launcher, workspaces, window title, apps, MPRIS, clock, weather, tray, recorder, notifications, clipboard, CPU/RAM/battery, control center, session power
- **Launcher**: list view, compact, recent-first sorting, DuckDuckGo web search, emoji (`:` trigger), calculator
- **Lock screen**: password + fingerprint + FIDO2/U2F parallel auth, video wallpaper from `~/media/animated/`
- **Greeter**: the greeter now ships as a **separate flake** (`duxlabs-dev/dux-greeter`, input `dank-greeter`), driven by `programs.dms-greeter` (Hyprland compositor). It syncs the user's DMS theme/wallpaper/settings into its cache dir `/var/lib/dms-greeter` (copied from `~/.config/DankMaterialShell/` etc. via `configHome`) before greetd starts.
- **Control center**: volume, brightness, WiFi, Bluetooth, audio I/O, DND, idle inhibitor, VPN, KDE Connect
- **Notifications**: 5s timeout (normal), persistent (critical), 50 history items, 7-day retention
- **Desktop widgets**: system monitor (CPU/RAM/network/disk) + weather forecast
- **Wallpaper**: cycling every 300s from `~/media/wallpapers/`
- **Power management**: AC: 10min screen off, 3min lock, 30min suspend. Battery: power-saver profile, 20min suspend.
- **Dynamic theming**: not enabled. only active to make dank set colors for gtk and qt apps.
- **Plugins**: dankbarPinentry, dankBatteryAlerts, dankKDEConnect, dankHyprlandWindows, dankDesktopWeather, displaySettings, developerUtilities, wallpaperCarousel, sessionPower, aiAssistant (Anthropic Claude)
- **AI assistant**: built-in, uses Anthropic Claude Opus 4

#### DMS Nix structure

- Greeter (`dank-greeter` flake input, `nixosModules.default` → `programs.dms-greeter`): greetd-based greeter with Hyprland as compositor, cache dir `/var/lib/dms-greeter`. Lives in its own repo now, not the DMS flake.
- Home Manager module (`homeModules.dank-material-shell`): 700+ lines of declarative config
- Plugin registry: separate flake input (`dms-plugins`)
- Pinentry (`dank-pinentry` flake input, `homeModules.default` → `programs.dank-pinentry`): the gpg-agent pinentry. Prompts in the terminal when one is usable, otherwise inside DankBar via the `dankbarPinentry` plugin (widget first in the right section, hidden when idle). The DMS aspect sets `services.gpg-agent.pinentry.package` to it; `security.nix` keeps pinentry-bemenu (Linux) / pinentry_mac as the `mkDefault`.

### Window management — `omniwm`

`modules/desktop/omniwm.nix` (aspect `omniwm`, included by `user-macos` since `programs.omniwm` is home-manager). Replaced yabai+skhd, which needed the scripting addition and therefore SIP disabled.

- **SIP stays enabled**; OmniWM is Developer ID signed and notarized, and nixpkgs unpacks the release artifact with `bsdtar` to keep that signature valid.
- **Hotkeys are built in**, so there is no skhd. Each hotkey id holds exactly **one** binding, so setting `focus.left = "Option+H"` *moves* it rather than adding an alias.
- `general.defaultLayoutType = "dwindle"` (closest to Hyprland), 8px gaps.
- Float rules use `appNameSubstring`/`titleRegex` rather than bundle IDs; `bundleId` may be `""` as long as another matcher is set. Each rule needs an explicit `id` UUID.
- **`settings.toml` is Nix-owned and the GUI fights it**: OmniWM rewrites the file from its Settings window and on version migration, replacing the symlink; `force = true` relinks ours on every switch. Any GUI change worth keeping must be mirrored into Nix, and new hotkey ids added by an upgrade need adding by hand.
- Requires macOS 26+, Accessibility + Input Monitoring, and `Displays have separate Spaces` **ON** (the default; OmniWM pauses until it is).
- No exec/launch command exists, so `alt+return` is `toggleQuakeTerminal` (Ghostty via libghostty) and 1Password moved to a Raycast hotkey. There is also no close-window command — `Cmd+W` covers it.

## Editing guidelines

- **Hyprland config**: Lua (`configType = "lua"`), never hyprlang — 0.56 removed that parser. All directional bindings use hjkl, no arrow keys; the modifier is `SUPER`, interpolated in Nix rather than a `$mainMod` variable. Verify new `hl.*` calls against `<hyprland>/share/hypr/stubs/hl.meta.lua`.
- **DMS greeter compositor config**: `programs.dms-greeter.compositor.customConfig` must also be Lua. dms-greeter picks its own appended launch snippet via `launcher.isHyprlandLuaConfig`, which sniffs the custom config for `hl.` (or a `.lua` suffix); without a match it appends a hyprlang `exec-once` line and the greeter dies before quickshell starts.

OmniWM bindings use hjkl with `Option` as the modifier, without arrow keys.

---
name: herdr-app
description: "Use when changing what the user sees in the Herdr App: opening a program in a pane, tab or space, showing an hc terminal, arranging or capturing the window, or editing mods and layouts."
---

# Window control

Use `herdr-app` to change what the user sees. Use the `herdr-core` skill for services, output and process cleanup that do not need a window change.

For persistent mod, layout, theme, setting or keybinding changes, read [Mod development](mod-development.md) before editing. Routine window operations follow the workflow below.

## 1. Know the route

In a Linux agent jail, `herdr-app` talks to an App proxy that the jail launcher started for this session. Run it directly, with no host approval. The proxy runs every program you start through the App inside this jail's Core and shows it in a `herdr-core-view` pane, so nothing you launch runs on the host. It refuses commands that would reach host programs: paste, mods, layout edits, settings, theme, updates, quit and remote machines. A refusal is final for this session; tell the user instead of routing around it through `host_exec`.

Outside the Linux jail, including Darwin, `herdr-app` drives the user's App directly and programs it starts run on the host. Follow the harness's approval policy there.

`herdr-app --help`, `herdr-app --skill` and `herdr-app commands` are local reference. Running bare `herdr-app` opens or raises the window, so use `ls` and `status` to inspect.

Proceed when you know which route applies.

## 2. Inspect

Run `herdr-app ls` and `herdr-app status` to identify the space, tab and pane you need and to check existing errors. Use `herdr-app commands` for argument names.

Proceed when the target IDs and requested change are clear. Prefer explicit targets where the command supports them. For focus-relative commands, verify the focused target first.

## 3. Act

Create or rearrange visible spaces, tabs and splits when the task or the user calls for it. Give new spaces and tabs useful names. Use returned IDs for later operations instead of guessing IDs or assuming focus stayed put.

### Start a program the user can watch

```sh
herdr-app do terminal.open --place right --name web --argv '["npm","run","dev"]'
herdr-app do tab.new --name tests --folder /path/to/project --argv '["cargo","test"]'
```

`terminal.open`, `tab.new`, `pane.split` and `space.new` accept `argv`, plus `folder` and `task` where `herdr-app commands` lists them. Without `argv` the pane gets a shell. In the jail, the reply carries two terminal IDs:

- `terminal` is the host pane's viewer. Use it for App commands such as `agent.focus` or `terminal.kill`.
- `sandbox_terminal` is the program in this jail's Core. Use it for `hc read`, `hc wait`, `hc send` and `hc kill`.

If the proxy answers that the sandbox Core is not running, run `hc ls` once to start it and retry.

### Show a terminal you already started with `hc`

Open a pane that attaches to it:

```sh
herdr-app do terminal.open --place right --name web --argv '["hc","attach","t4"]'
```

Closing that pane detaches without stopping the program.

### Close what you opened

In the jail, `pane.close`, `tab.close`, `space.close`, `terminal.kill`, `terminal.keep` and `terminal.park` accept only targets created through the proxy in this session, named explicitly. The user's own panes stay theirs. Closing a pane leaves the jail program running; end it with `hc kill <sandbox_terminal>`. After a `tab.new` or `space.new` program exits, its pane falls back to a host shell for the user.

Proceed when the command named the intended operation and target.

## 4. Verify

Read the command result and keep any created IDs. Check `ls` or `status` for the intended placement or focus and for new errors. A successful launch reply does not prove the program started correctly; read its `sandbox_terminal` with `hc read` as well.

For visual changes, run `herdr-app shot <path>.png` and inspect the image. In the jail the path must lie inside the workspace, for example under `.dev-skills/`. The screenshot shows Herdr's window, not the application under test. Use App commands rather than pointer or keyboard automation against the user's desktop.

Report the observed result and any remaining error. Leave the user's App and Core running; a window operation never needs a restart.

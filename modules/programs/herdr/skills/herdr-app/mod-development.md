# Mod development through Nix

Read this file when changing a mod, layout, theme, setting or keybinding. Routine window control does not require it.

## 1. Find the owner and supported API

In the Nix configuration repository, read `docs/herdr.md` and the relevant declarations in `modules/programs/herdr/herdr.nix`. Inspect the existing assets before introducing another implementation.

Read the installed App guide and the relevant generated `.d.ts` declarations through an approved host route, or inspect their matching packaged source. Use `herdr-app commands` to confirm command names and arguments. The installed guide describes upstream capabilities; the repository's Nix ownership and approval rules govern how to apply them.

Proceed when you have identified the owning source, its callers or layout placement, and the API the change needs.

## 2. Change the declarative source

Keep reusable asset sources beside the Herdr module and declare their installation in Nix. Reuse the repository's package and helper conventions. Manage individual assets instead of replacing the whole App home.

Keep `settings.json` Home Manager-managed and session, window and mod runtime state writable. Preserve Home Manager's collision protection; back up unmanaged files before taking ownership rather than forcing replacement.

Use the App's theme colors for custom UI. Keep lifecycle state and real terminal IDs separate from supplementary display data. If an upstream asset needs modification, derive it from the packaged source with a patch that fails when its expected anchor changes.

The App regenerates its installed guide. Change the package's embedded-guide patch rather than editing the generated file. Leave generated type declarations untouched. Upstream installer, updater and clone examples are references, not the deployment procedure for this machine.

Proceed when the requested behavior is defined in repository source and no persistent change depends on editing an installed managed file.

## 3. Verify the built assets

Evaluate or build the affected Home Manager outputs using `docs/system.md`. Exercise the rendered installation, including store symlinks, rather than checking only an unpacked source directory.

For a changed mod, run `herdr-app check <installed-mod-directory>` in a private App home, Core session and display. Then exercise the changed behavior, inspect `status`, and view an App screenshot. A successful one-frame check does not prove interaction behavior. A still-working window can also be the previous module retained after a failed reload.

For layouts and keybindings, exercise the affected actions in that private session. Do not automate the user's real desktop. If a required runtime check is unavailable, report exactly what remains unverified.

Proceed when the built assets load without new errors and the changed behavior has been observed.

## 4. Apply through the system workflow

Follow `docs/system.md` for activation. On Linux, use the approved host route or have the user run the rebuild. Coordinate an App relaunch when the package or embedded guide changed; do not restart Core merely to refresh the guide.

After activation, verify the live result through the approved App route. If activation, relaunch or live verification is pending, report it as pending. A successful build alone does not mean the change is installed.

# Trackpad Control

Trackpad Control is a small native macOS menu bar utility built with SwiftUI. It lives in the menu bar and lets you toggle the macOS setting that ignores the built-in trackpad when a mouse or wireless trackpad is present.

[![Download ZIP](https://img.shields.io/badge/Download-ZIP-blue)](https://github.com/RitamCODE/mac_toucpad_menu_toggle/releases/latest/download/TrackpadControl-macOS.zip)
[![Latest Release](https://img.shields.io/github/v/release/RitamCODE/mac_toucpad_menu_toggle)](https://github.com/RitamCODE/mac_toucpad_menu_toggle/releases/latest)

## What it does

- Runs as a menu bar app using `MenuBarExtra`
- Shows the current setting state
- Toggles the setting through preference writes plus a System Settings UI-scripting fallback when needed
- Requests Accessibility access when macOS requires it for UI automation

## Project layout

- `TrackpadControl.xcodeproj`: Xcode project
- `TrackpadControl/`: app source code
- `scripts/package_release.sh`: release packaging script

## Run locally

1. Open `TrackpadControl.xcodeproj` in Xcode 15 or newer.
2. Select the `TrackpadControl` scheme.
3. In `Signing & Capabilities`, choose your Apple Developer team or Personal Team.
4. Keep the bundle identifier unique, for example `com.ritam.TrackpadControl`.
5. Build and run on macOS 13 or newer.
6. The app appears in the menu bar as `Trackpad Control`.

## Accessibility permission

The app may need Accessibility permission to automate the real System Settings checkbox.

If macOS prompts you, allow it.

If you need to enable it manually:

1. Open `System Settings`
2. Go to `Privacy & Security > Accessibility`
3. Enable `TrackpadControl`

If you later change the bundle identifier or signing identity, macOS may require permission again.

## GitHub upload

If you already have a GitHub repo created:

```bash
git remote add origin https://github.com/<your-user>/<your-repo>.git
git push -u origin main
```

If you have not created the GitHub repo yet, create an empty repo on GitHub first, then run the commands above.

## Build downloadable files

To build local release artifacts:

```bash
./scripts/package_release.sh
```

This creates:

- `dist/TrackpadControl.app`
- `dist/TrackpadControl-macOS.zip`

Upload `dist/TrackpadControl-macOS.zip` to GitHub Releases. The button at the top of this README is wired to that exact filename.

## Install from the ZIP

Because this app is not notarized, macOS may block it on first launch.

Recommended install steps:

1. Download `TrackpadControl-macOS.zip` from the latest GitHub Release.
2. Unzip it.
3. Move `TrackpadControl.app` into `Applications`.
4. Remove the quarantine flag in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/TrackpadControl.app
```

5. Open `TrackpadControl.app` from `Applications`.

If you keep the app somewhere else, replace `/Applications/TrackpadControl.app` with the real path.

## Public distribution

If you want other people to download it without Gatekeeper warnings, you should:

1. Sign the app with a valid Apple Developer certificate.
2. Notarize the archive with Apple.
3. Staple the notarization ticket.
4. Upload the notarized `.zip` to a GitHub Release.

The current repo is ready for that flow, but the actual signing certificate, notarization profile, and Apple account setup must be done in Xcode / Apple Developer settings on your machine.

## Create a GitHub Release

After the release files are created:

1. Open your GitHub repo.
2. Go to `Releases`.
3. Click `Draft a new release`.
4. Create a tag like `v1.0.0`.
5. Upload:
   - `dist/TrackpadControl-macOS.zip`
6. Publish the release.

After that, users can download directly from the README buttons at the top of this page.

## Notes

- The app is configured as a menu bar utility using `LSUIElement`, so it does not create a normal Dock app window.
- The primary implementation reads and writes the `USBMouseStopsTrackpad` preference in:
  - `com.apple.AppleMultitouchTrackpad`
  - `com.apple.driver.AppleBluetoothMultitouch.trackpad`
- After writing, the app refreshes its state by reading the same preference keys back.

## Automation notes

- Normal preference reads and writes do not require Accessibility permission.
- A best-effort UI-scripting fallback is included for cases where the preference keys do not reflect the live setting correctly.
- If that fallback is needed, macOS may prompt you to grant Accessibility access to the app.
- UI scripting is sensitive to macOS version changes, localization, and System Settings layout changes.

## Known limitations

- Apple does not expose a dedicated public Swift API for this setting, so the app relies on preference writes plus a UI-scripting fallback.
- Exact status detection is best effort. If the expected keys are missing or the two domains disagree, the app reports `Unknown`.
- The UI-scripting fallback depends on the current `System Settings` UI hierarchy for the `Pointer Control` pane. If Apple changes that layout or label, `TrackpadAutomationService.swift` may need adjustment.
- A locally shared zip will show a macOS warning until the app is signed with Developer ID and notarized.

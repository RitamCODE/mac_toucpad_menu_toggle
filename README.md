# Trackpad Control

Trackpad Control is a small native macOS menu bar utility built with SwiftUI. It lives in the menu bar and lets you toggle the macOS setting that ignores the built-in trackpad when a mouse or wireless trackpad is present.

## Project layout

- `TrackpadControl.xcodeproj`: Xcode project
- `TrackpadControl/`: Swift sources, assets, and app metadata

## How to run

1. Open `TrackpadControl.xcodeproj` in Xcode 15 or newer.
2. Select the `TrackpadControl` scheme.
3. Build and run the app on macOS 13 or newer.
4. The app appears in the menu bar with the title `Trackpad Control`.

## GitHub upload

If this repo is not connected to GitHub yet:

```bash
cd /Users/ritam/Projects/mac_toucpad_menu_toggle
git init
git add .
git commit -m "Initial Trackpad Control app"
git branch -M main
git remote add origin https://github.com/<your-user>/<your-repo>.git
git push -u origin main
```

If the repo already exists on GitHub, only the last three commands are needed after the first commit.

## Making the app downloadable

### Minimal downloadable build

This is enough to share a `.zip` with people you trust, but macOS may warn because the app is not notarized.

1. In Xcode, open the `TrackpadControl` target.
2. In `Signing & Capabilities`, choose your Apple Developer team or Personal Team.
3. Keep the bundle identifier unique, for example `com.ritam.TrackpadControl`.
4. Build the Release app:

```bash
cd /Users/ritam/Projects/mac_toucpad_menu_toggle
./scripts/package_release.sh
```

That script creates:

- `dist/TrackpadControl.app`
- `dist/TrackpadControl-macOS.zip`

### Public downloadable build

If you want other people to download it without Gatekeeper warnings, you should:

1. Sign the app with a valid Apple Developer certificate.
2. Notarize the archive with Apple.
3. Staple the notarization ticket.
4. Upload the notarized `.zip` to a GitHub Release.

The current repo is ready for that flow, but the actual signing certificate, notarization profile, and Apple account setup must be done in Xcode / Apple Developer settings on your machine.

## Creating a GitHub Release

After `dist/TrackpadControl-macOS.zip` is created:

1. Open your GitHub repo.
2. Go to `Releases`.
3. Click `Draft a new release`.
4. Create a tag like `v1.0.0`.
5. Upload `dist/TrackpadControl-macOS.zip`.
6. Publish the release.

People can then download the zip from the release page.

## Notes

- The app is configured as a menu bar utility using `LSUIElement`, so it does not create a normal Dock app window.
- The primary implementation reads and writes the `USBMouseStopsTrackpad` preference in:
  - `com.apple.AppleMultitouchTrackpad`
  - `com.apple.driver.AppleBluetoothMultitouch.trackpad`
- After writing, the app refreshes its state by reading the same preference keys back.

## Accessibility and automation

- Normal preference reads and writes do not require Accessibility permission.
- A best-effort UI-scripting fallback is included for cases where the preference keys do not reflect the live setting correctly.
- If that fallback is needed, macOS may prompt you to grant Accessibility access to the app.
- UI scripting is sensitive to macOS version changes, localization, and System Settings layout changes.
- If you change the app bundle identifier or signing identity, macOS Accessibility permission may need to be granted again.

## Known limitations

- Apple does not expose a dedicated public Swift API for this setting, so the app relies on preference writes plus a UI-scripting fallback.
- Exact status detection is best effort. If the expected keys are missing or the two domains disagree, the app reports `Unknown`.
- The UI-scripting fallback depends on the current `System Settings` UI hierarchy for the `Pointer Control` pane. If Apple changes that layout or label, `TrackpadAutomationService.swift` may need adjustment.

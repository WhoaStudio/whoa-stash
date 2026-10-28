# Whoa Stash

A macOS menu-bar app that puts controls and glanceable info on the edges of the screen.
It has no Dock icon (`LSUIElement`) and only shows one while Preferences is open.

| Surface | Where it appears | What it does |
|---|---|---|
| Brightness band | Middle of the left edge (left or right, set in Preferences) | Scroll to set the brightness of the display it is on. The built-in display goes through DisplayServices. External monitors use DDC/CI over I2C, or DisplayServices for Apple displays that don't expose DDC. |
| Volume dial | Top-left corner | Scroll to set the default output device's volume. |
| Edge slider | Right edge | Volume slider. |
| Side panel | Top-right corner | Usage rings for Claude Code and GitHub Copilot, one panel per screen. |
| Notch panel | Top centre, folded onto the notch (or a pill on screens without one) | Unfolds on hover or with a global shortcut. Tabs: **Global** (today's agenda), **Calendar** (month grid, agenda, three-week strip), **Tray** (a 4-file drop shelf), **Mirror** (live camera preview in a circle, with a brightness slider for the preview only), **AI** (the same usage rings). |

## Requirements

- macOS 26.5 or later (the deployment target)
- Xcode 26.6 (the version this README was checked with)
- No third-party dependencies and no Swift packages

## Build and run

Open `whoa-stash.xcodeproj` and run the `whoa-stash` scheme (⌘R), or from the terminal:

```bash
xcodebuild -scheme whoa-stash -destination 'platform=macOS' build
```

```bash
open "$(xcodebuild -scheme whoa-stash -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR /{print $3}')/whoa-stash.app"
```

Signing is automatic and uses the team set in the project (`2MPVX5W6KB`). To build on another account, change the team under *Signing & Capabilities*.

TODO: there is no release, archive or notarization process in the repo yet.

### What the app asks for

- **Calendars** (full access). The notch panel requests it the first time it loads the agenda. If you deny it, the panel shows an access-denied card.
- **Camera.** The Mirror tab asks the first time it is shown. The camera runs only while the panel is unfolded on that tab; the green LED goes off as soon as it folds or you switch tab. If you deny it, the tab shows a card that opens System Settings.
- **Keychain items owned by other apps.** The usage rings read the OAuth tokens that Claude Code (`Claude Code-credentials*`) and GitHub (`github-copilot-app` or `gh:github.com`) store. macOS asks you to allow each one on the first read. If you refuse, that ring shows as unavailable. Tokens stay in memory only.
- The app is not sandboxed (`ENABLE_APP_SANDBOX = NO`).
- Info.plist declares an Accessibility usage string, but no code path requests Accessibility today (`AccessibilityPermissionService` is unused).

For the Claude ring, log in to Claude Code on the machine. For the Copilot ring, sign in to the GitHub Copilot app or the GitHub CLI.

## Development launch flags

Pass them after `--args` in the `open` command above, or add them to the scheme's *Arguments Passed On Launch*.

| Flag | Effect |
|---|---|
| `--show-settings[=general\|brightness\|about]` | Opens Preferences on that pane (default `general`). |
| `--show-notch-panel` | Unfolds the notch panel without hovering. |
| `--notch-tab=global\|calendar\|tray\|mirror\|ai` | With `--show-notch-panel`, unfolds on that tab. |
| `--show-usage-panel` | Opens the side panel without hovering. |
| `--show-volume-dial` | Opens the volume dial without hovering. |
| `--claude-usage=<session>,<weekly>` | Fixed Claude percentages, for example `73,7`. Skips the network and Keychain. |
| `--copilot-usage=<percent>` | Fixed Copilot percentage. |
| `--camera-mirror=granted\|denied\|notDetermined` | Fake camera for the Mirror tab: a gradient instead of video, with the given access state. |
| `--calendar-agenda=granted\|denied\|notDetermined` | A fixed sample day with the given access state. |

## Tests

```bash
xcodebuild -scheme whoa-stash -destination 'platform=macOS' test
```

Run a single suite:

```bash
xcodebuild -scheme whoa-stash -destination 'platform=macOS' -only-testing:whoa-stashTests/SettingsStorageTests test
```

The suite has 61 tests: 59 in Swift Testing across 10 suites, and 2 in XCTest (`CopilotUsageTests`).

TODO: there is no linter, formatter or CI configured.

## Project structure

```
whoa-stash/
  App/          entry point, AppDelegate (composition root), menu-bar item, Dock presence
  Core/         shared code: settings, logging, theme, geometry, animation, shortcuts
  Features/     one folder per surface: Brightness, EdgeSlider, Volume, SidePanel,
                NotchPanel, PanelTabs (notch tab contents), Settings (Preferences window)
  Resources/    asset catalog (app icon, menu-bar glyph)
whoa-stashTests/  unit tests
Design/Icon/      icon source SVGs (see Design/Icon/README.md)
AppIcons/         older generated icon pack, not used by the build
docs/             architecture and debugging notes
```

More detail: [docs/architecture.md](docs/architecture.md), [docs/external-interfaces.md](docs/external-interfaces.md), [docs/debugging.md](docs/debugging.md).

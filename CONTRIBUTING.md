# Contributing to Whoa Stash

Thanks for your interest. Bug reports, fixes and small features are welcome. For anything large,
open an issue first so we can agree on the approach before you write code.

## Setup

You need macOS 26.5 or later and Xcode 26.6 (see `.xcode-version`). The project has no Swift
packages, so there is nothing to install.

```bash
git clone https://github.com/WhoaStudio/whoa-stash.git
cd whoa-stash
```

### Building without the maintainer's signing team

The project signs with the maintainer's team (`2MPVX5W6KB`). Without that account, Xcode stops
with "No Account for Team". Clear the team and sign to run locally:

```bash
xcodebuild -scheme whoa-stash -destination 'platform=macOS' DEVELOPMENT_TEAM= CODE_SIGN_IDENTITY=- build
```

```bash
xcodebuild -scheme whoa-stash -destination 'platform=macOS' DEVELOPMENT_TEAM= CODE_SIGN_IDENTITY=- test
```

In the Xcode app, pick your own team under *Signing & Capabilities* instead, and don't commit that
change.

Ad-hoc signed builds get a new code signature on every build, so macOS may ask again for Keychain,
Calendar, Camera or Accessibility access. Most surfaces can be checked without any of them through
the launch flags in the [README](README.md#development-launch-flags), for example
`--claude-usage=73,7` or `--now-playing=playing`.

## Making a change

1. Fork the repo and branch off `stable` (the default branch; there is no `main`).
2. Keep the change focused. Don't reformat or refactor unrelated code.
3. Run the tests. CI runs the same build and test commands on every pull request.
4. Open a pull request against `stable` and fill in the template.

## Conventions

The full list is in [CLAUDE.md](CLAUDE.md). The ones reviewers check most:

- Doc comments, log messages and test names are in **French**.
- The module defaults to `@MainActor`. Mark code called from C callbacks or background queues
  `nonisolated`.
- Log through `Log.<category>`, never `print`. Keep user-derived strings private.
- Only `SettingsStorage` and `FileShelfStore` touch `UserDefaults`.
- New `AppSettings` fields need defaults, and decoding must keep tolerating missing or unknown keys.
- External sources (network, Keychain, calendar…) go behind a protocol with a `Mock…Provider`, so
  the UI can be checked without them.
- Tests use Swift Testing (`@Suite` / `@Test`).
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/), for example
  `fix(notch-panel): …`.

Never commit tokens, client IDs, `.env` files or local Xcode state (`xcuserdata/`).

## Claude Code tooling

`.claude/` holds the maintainer's Claude Code setup. If you use Claude Code in this repo, its hooks
run with `node`. Ignore the folder if you don't use Claude Code.

## Reporting security issues

Don't open a public issue. See [SECURITY.md](SECURITY.md).

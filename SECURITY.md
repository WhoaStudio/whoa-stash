# Security policy

Whoa Stash reads OAuth tokens that other apps store in the Keychain (Claude Code, GitHub Copilot,
the GitHub CLI) and keeps Spotify tokens in its own Keychain item. Issues that could leak those
tokens, or let another process drive the app, matter to us.

## Reporting a vulnerability

Please report privately through GitHub:
[Report a vulnerability](https://github.com/WhoaStudio/whoa-stash/security/advisories/new).
Don't open a public issue or pull request.

Include what you found, how to reproduce it and the macOS version. We aim to reply within a week.

## Supported versions

There are no releases yet. Only the latest commit on `stable` is supported.

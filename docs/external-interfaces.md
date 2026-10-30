# External interfaces

The app serves nothing. It consumes three undocumented HTTP endpoints (Claude, Copilot, Codex),
reads Keychain items and files owned by other apps, and uses several TCC permissions. These can change without notice, so this
file records exactly what the code expects.

## HTTP

All three calls are `GET`, made from the `…UsageService` types in `Features/SidePanel/Services/`.
Any non-2xx response throws `badStatus`, and a payload without the expected keys throws
`unrecognizedPayload(keys:)` with the keys actually received. Either error becomes
`.unavailable(reason:)` in the view model, and the ring shows as unavailable. Polling interval:
60 s (Claude and Copilot).

| Source | Endpoint | Headers | Fields read |
|---|---|---|---|
| Claude | `https://api.anthropic.com/api/oauth/usage` | `Authorization: Bearer <token>`, `anthropic-beta: oauth-2025-04-20` | Session window from the first of `five_hour` / `fiveHour` / `session`. Weekly window from `seven_day` / `sevenDay` / `all_models` / `week`. Inside each: `utilization` (0–100, also `used_percent`, `percent_used`, `percentage`) and `resets_at` (also `resetsAt`, `reset_at`). |
| Copilot | `https://api.github.com/copilot_internal/user` | `Authorization: Bearer <token>`, `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28` | `quota_snapshots.premium_interactions.percent_remaining` (shown as 100 − value) and `quota_reset_date_utc`, falling back to `quota_reset_date`. |
| Codex | `https://chatgpt.com/backend-api/wham/usage` | `Authorization: Bearer <token>`, `User-Agent: codex-cli`, `chatgpt-account-id` when known | `rate_limit.primary_window` / `secondary_window`, told apart by `limit_window_seconds` (5 h vs weekly). TODO: `CodexUsageService` is not instantiated by `AppDelegate` today, so this call is not made. |

The parsers are `ClaudeUsageService.parse(_:)`, `CopilotUsageService.parse(_:)` and `CodexUsageService.parse(_:)`.
`CopilotUsageTests` covers the Copilot parser. When an endpoint changes shape, add the new
key to the fallback list first.

## IMAP (new mail in the notch)

`IMAPMailSource` opens a TLS connection (`Network.framework`, default certificate checks) straight
from the Mac to the server set in Preferences ▸ Mail, usually port 993. It signs in with `LOGIN`,
opens the inbox read-only (`EXAMINE`), waits with `IDLE`, and on `* n EXISTS` runs
`UID FETCH <last+1>:*` for `FROM`, `SUBJECT`, `MESSAGE-ID`, the content headers and the first 6 KiB of
`BODY.PEEK[TEXT]`. Nothing is marked as read and nothing is stored: only sender, subject and a
one-line preview are kept in memory while the notch shows them. `IDLE` is restarted every 10 minutes
(and the connection is closed if the server does not answer `DONE` within 30 s). A lost connection is
retried after 5 s, doubling up to 5 min, and the messages missed meanwhile (at most 5) are shown after
reconnecting. Sender, subject and server name are logged as private.

Sign-in is a password or app-specific password (iCloud, Gmail with 2-step verification). OAuth
(`XOAUTH2`, needed for Outlook.com and for Gmail without an app password) is not implemented.

## Keychain

All reads are generic-password reads. Tokens are cached in memory only, and are never written
to disk or logged.

| Store | Item service | Notes |
|---|---|---|
| `IMAPCredentialStore` | `ugolin-olle.whoa-stash.imap`, account `<user>@<host>` | The IMAP password, as UTF-8. Written from Preferences ▸ Mail, read when connecting. |
| `ClaudeUsageCredentialStore` | `Claude Code-credentials` or `Claude Code-credentials-<hash>` | Finds the item by attributes first (no prompt), takes the most recently modified one, then reads its data through `/usr/bin/security find-generic-password -w` (no prompt). The JSON is `claudeAiOauth.accessToken` plus `expiresAt` in **milliseconds**. The token is cached until 30 s before expiry, or for 5 min when there is no expiry. An expired token raises "relance `claude`". |
| `CopilotUsageCredentialStore` | `github-copilot-app`, then `gh:github.com` | The value may be `go-keyring-base64:`-prefixed (GitHub CLI). It must start with `gho_`, `ghp_` or `github_pat_`. Cached for 5 min. |

The Claude item's data is read through `/usr/bin/security`, as Claude Code does itself, not with
`SecItemCopyMatching`. Claude Code rewrites the item with `security add-generic-password -U` on
every token refresh, which resets its partition list to `apple-tool:` and drops the `teamid:` that
"Always Allow" adds. A direct read would prompt again after every refresh. `/usr/bin/security` is
in the item's ACL and matches `apple-tool:`, so it never prompts.

## Local files

| Reader | Path | Notes |
|---|---|---|
| `CodexUsageCredentialStore` | `$CODEX_HOME/auth.json`, else `~/.codex/auth.json` | Reads `tokens.access_token` and `tokens.account_id`. Held in memory only, never rewritten. |
| `AgentActivityProviding` (activity logs) | `~/.claude/projects`, `~/.codex/sessions`, `~/.codex/archived_sessions` (`*.jsonl`) | TODO: not wired into `AppDelegate` today. |

## Hardware

`SPUAccelerometerSensor` (Knock) reads the chassis accelerometer through `AppleSPUHIDDevice`
(usage page `0xFF00`, usage 3) after waking `AppleSPUHIDDriver`. The sensor is undocumented and
Apple silicon only; when it is missing the code degrades instead of failing.

## Permissions

New mail needs none: the app is not sandboxed, so outgoing connections are allowed, and no
entitlement was added.

| Permission | Requested by | Fallback |
|---|---|---|
| Calendars, full access (`NSCalendarsFullAccessUsageDescription`) | `EventKitCalendarService.requestAccess()`, only while the status is `.notDetermined` | Notch panel shows the denied card |
| Camera (`NSCameraUsageDescription`) | Mirror tab (`AVCameraMirrorService`), the first time the tab is shown | The tab shows a card that opens System Settings |
| Apple Events to Music (`NSAppleEventsUsageDescription`) | `AppleMusicQueueProvider`, through `/usr/bin/osascript`, on the first read of the Apple Music queue | The Playing Next column stays empty |
| Accessibility (`NSAccessibilityUsageDescription`) | `AccessibilityPermissionService`, from the Knock controller and its Preferences pane, when the chosen action needs it (lock screen) | The action is skipped |

The Info.plist strings are in French and live in the target's build settings
(`INFOPLIST_KEY_…`, generated Info.plist). There is no Info.plist file.

## Now Playing

- **System now-playing source.** `MediaRemoteNowPlayingProvider` runs `/usr/bin/perl` with the vendored
  `mediaremote-adapter` (`Vendor/MediaRemoteAdapter`, shipped as `MediaRemoteAdapter.bin` plus the
  `.pl` script in Resources) and reads its JSON stream. It is the only route to MediaRemote since
  macOS 15.4, and it relies on a private framework.
- **Playing Next, Apple Music.** `AppleMusicQueueProvider` asks Music for the next tracks of the
  current playlist through `osascript`. It returns nothing while shuffle is on.
- **Playing Next, Spotify.** `SpotifyQueueProvider` calls `GET https://api.spotify.com/v1/me/player/queue`
  with the user's account. Sign-in is OAuth 2 PKCE (`SpotifyAuthorizer`): the browser opens once, and
  Spotify redirects to `http://127.0.0.1:48731/callback`, served by a loopback socket that only
  listens while connecting. The user creates the Spotify app, registers that redirect URI and pastes its
  Client ID in Preferences, General. Tokens live in the Keychain (service
  `ugolin-olle.whoa-stash.spotify`), never in `UserDefaults`. Scope: `user-read-playback-state`.
- Launch flags: `--now-playing=playing|paused`, `--playing-next=mock`.

# External interfaces

The app serves nothing. It consumes two undocumented HTTP endpoints, reads Keychain items
owned by other apps, and uses one TCC permission. These can change without notice, so this
file records exactly what the code expects.

## HTTP

Both calls are `GET`, made from the `…UsageService` types in `Features/SidePanel/Services/`.
Any non-2xx response throws `badStatus`, and a payload without the expected keys throws
`unrecognizedPayload(keys:)` with the keys actually received. Either error becomes
`.unavailable(reason:)` in the view model, and the ring shows as unavailable. Polling interval:
60 s.

| Source | Endpoint | Headers | Fields read |
|---|---|---|---|
| Claude | `https://api.anthropic.com/api/oauth/usage` | `Authorization: Bearer <token>`, `anthropic-beta: oauth-2025-04-20` | Session window from the first of `five_hour` / `fiveHour` / `session`. Weekly window from `seven_day` / `sevenDay` / `all_models` / `week`. Inside each: `utilization` (0–100, also `used_percent`, `percent_used`, `percentage`) and `resets_at` (also `resetsAt`, `reset_at`). |
| Copilot | `https://api.github.com/copilot_internal/user` | `Authorization: Bearer <token>`, `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28` | `quota_snapshots.premium_interactions.percent_remaining` (shown as 100 − value) and `quota_reset_date_utc`, falling back to `quota_reset_date`. |

The parsers are `ClaudeUsageService.parse(_:)` and `CopilotUsageService.parse(_:)`.
`CopilotUsageTests` covers the Copilot parser. When an endpoint changes shape, add the new
key to the fallback list first.

## Keychain

All reads are generic-password reads. Tokens are cached in memory only, and are never written
to disk or logged.

| Store | Item service | Notes |
|---|---|---|
| `ClaudeUsageCredentialStore` | `Claude Code-credentials` or `Claude Code-credentials-<hash>` | Finds the item by attributes first (no prompt), takes the most recently modified one, then reads its data (prompts once). The JSON is `claudeAiOauth.accessToken` plus `expiresAt` in **milliseconds**. The token is cached until 30 s before expiry, or for 5 min when there is no expiry. An expired token raises "relance `claude`". |
| `CopilotUsageCredentialStore` | `github-copilot-app`, then `gh:github.com` | The value may be `go-keyring-base64:`-prefixed (GitHub CLI). It must start with `gho_`, `ghp_` or `github_pat_`. Cached for 5 min. |

The Keychain grant belongs to the item, not to the service name. When Claude Code writes a new
item, macOS prompts again. That is expected behaviour, not a bug.

## Permissions

| Permission | Requested by | Fallback |
|---|---|---|
| Calendars, full access (`NSCalendarsFullAccessUsageDescription`) | `EventKitCalendarService.requestAccess()`, only while the status is `.notDetermined` | Notch panel shows the denied card |
| Accessibility (`NSAccessibilityUsageDescription`) | Nobody at present. `AccessibilityPermissionService` exists but has no callers. | — |

Both Info.plist strings are in French and live in the target's build settings
(`INFOPLIST_KEY_…`, generated Info.plist). There is no Info.plist file.

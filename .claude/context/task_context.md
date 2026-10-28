# Task context

## Goal

Redesign the notch panel's AI tab to match the user's "Usage" screenshot (header with provider tabs, selected-provider card, filter pills, Activity section). Notch only; no data-layer changes.

## Status

- Explored: `NotchPanelContentView` (AI tab = `aiColumns`: rings + `ClaudeUsagePanelView` card), `NotchPanelGeometry` (shared `tabContentHeight`, card 270x172), `SidePanelGeometry.ringSlots` (Claude, Copilot connected; Codex, Gemini not), `UsageMarkPath` icons.
- Copilot state is not wired to the notch yet (AppDelegate only sends it to the side panel).
- Plan proposed in chat; waiting for approval. No code edited.

## Next steps

1. Get answers on panel height, tab mapping and placeholder handling.
2. Implement per the approved plan.

## Open questions

- Grow the panel for every tab, or only while AI is selected?
- No data for resets available, activity metrics, filters, landscape image: TODO placeholders.

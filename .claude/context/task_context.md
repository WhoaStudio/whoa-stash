# Task context

## Goal

Add an AirDrop drop zone to the Tray tab: while a file is dragged over the notch panel, the tray shows two targets, "Keep in tray" (current behavior) and "AirDrop" (opens the system AirDrop picker via `NSSharingService(named: .sendViaAirDrop)`).

## Status

- Explored: `NotchPanelContentView` is the only drop target (whole panel) and forwards to `FileTrayView.canAccept/accept/setDropHighlighted`. `FileShelfStore.add` moves files into the tray folder.
- Plan proposed in chat; waiting for approval. No code edited.

## Next steps

1. Get approval / answers to open questions.
2. Implement: drop-target enum + hit test in `FileTrayView`, AirDrop zone view, route `draggingUpdated`/`performDragOperation` by zone.
3. Build with `xcodebuild -scheme whoa-stash -destination 'platform=macOS' build`, run tests.

## Open questions

- Cursor outside the tray rect (e.g. over the notch at the top): default to Keep?
- Allow AirDropping files already in the tray (dragged from a tile)?

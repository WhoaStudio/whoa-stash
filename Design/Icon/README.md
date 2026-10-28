# Whoa Stash — icon

A drawer pulled out of its bay on a dark panel: the stash itself, sliding out of the edge
of the screen. One object, three shapes, no fine detail — it survives down to 16 px.

## Files

| File | What it is |
|---|---|
| `icon-master.svg` | The master, 1024 canvas. Drives every size from 64 px up. |
| `icon-small.svg` | Small-size cut for 16 and 32 px: the bay is dropped, the drawer is larger. |
| `menubar.svg` | Menu-bar template glyph, 18 pt square. Opaque areas get tinted by AppKit, so the handle is a real hole (`fill-rule="evenodd"`). |
| `icon-1024.png` | Rendered master, for stores and marketing. |

## Colour

| Role | HEX |
|---|---|
| Shell, deepest | `#04281C` |
| Shell, mid | `#0C7A50` |
| Shell, bright | `#17B873` |
| Shell, highlight | `#39FF88` |
| Panel | `#15181A` → `#06080A` |
| Drawer | `#FFFFFF` |
| Handle | `#0A0C0E` |

`#39FF88` is a brighter, softer green than `OverlayPalette.activeGreen` (`#00FF00`), the active
tick colour in the brightness and volume overlays. TODO: the icon and the overlays were meant to share one green; they no longer do.

## Construction

- 1024 canvas; the tile is an 824 px superellipse (`n = 5`), centred, leaving the 100 px
  margin macOS expects. A drop shadow is baked into `icon-master.svg` for the PNG export.
- The dark panel is centred horizontally and sits against the top of the tile, so the green
  reads as a band along the bottom rather than an even frame.
- No live text, no rasters. The only filter is the macOS drop shadow on the master.

## Where it is wired

- `whoa-stash/Resources/Assets.xcassets/AppIcon.appiconset` — app icon, 16 → 1024.
  `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` already points at it.
- `whoa-stash/Resources/Assets.xcassets/MenuBarIcon.imageset` — template glyph used by
  `StatusBarController`.

## Regenerating

`icon-master.svg` and `icon-small.svg` are the source of truth. Export at 16, 32, 64, 128,
256, 512 and 1024 with transparency, using the small cut for 16 and 32, then drop the PNGs
into `AppIcon.appiconset` as `icon_<size>.png`.

## Not covered

- No trademark search was done. Run one before using this commercially.
- `AppIcons/` at the repo root is an older generated pack (the purple ring) and is now out
  of date; it is not what the app builds with.

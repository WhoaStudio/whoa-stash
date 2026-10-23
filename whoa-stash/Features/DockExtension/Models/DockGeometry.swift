import AppKit

/// Position/taille actuelles du Dock système, dans le repère écran d'AppKit (origine en bas).
struct DockGeometry {
    let frame: NSRect
    let screen: NSScreen
    let tileSize: CGFloat
}

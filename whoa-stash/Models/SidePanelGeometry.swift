import AppKit

/// Géométrie du panneau latéral pour un écran donné : la zone sensible collée au coin supérieur
/// droit, et le cadre du panneau qui s'y rattache. Tout est exprimé en coordonnées globales
/// AppKit (origine en bas à gauche de l'écran principal, axe Y vers le haut).
enum SidePanelGeometry {

    /// Zone sensible : 100 pt de haut sur 20 pt de large, mesurée depuis le bord droit.
    static let hotZoneWidth: CGFloat = 20
    static let hotZoneHeight: CGFloat = 100

    /// Proportions verticales : le panneau est une colonne accrochée au bord, pas une bulle
    /// horizontale — c'est ce qui lui donne sa silhouette de référence.
    static let panelWidth: CGFloat = 100
    static let panelHeight: CGFloat = 420

    /// Marge sous le bas de la barre de menus, pour que le panneau ne soit pas soudé à elle.
    static let topInset: CGFloat = 8

    static func hotZone(on screen: NSScreen) -> NSRect {
        let frame = screen.frame
        return NSRect(
            x: frame.maxX - hotZoneWidth,
            y: frame.maxY - hotZoneHeight,
            width: hotZoneWidth,
            height: hotZoneHeight
        )
    }

    /// Cadre affleurant le bord droit de l'écran : c'est depuis ce bord que le contenu glisse,
    /// donc le panneau doit y toucher — l'espacement visuel vient des coins arrondis, pas d'une
    /// marge. Le haut suit `visibleFrame` pour rester sous la barre de menus.
    static func panelFrame(on screen: NSScreen) -> NSRect {
        let top = screen.visibleFrame.maxY - topInset
        return NSRect(
            x: screen.frame.maxX - panelWidth,
            y: top - panelHeight,
            width: panelWidth,
            height: panelHeight
        )
    }
}

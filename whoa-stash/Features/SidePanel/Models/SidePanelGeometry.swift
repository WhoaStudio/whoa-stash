import AppKit

/// Géométrie du panneau latéral pour un écran donné : la zone sensible collée au coin supérieur
/// droit, le cadre du panneau qui s'y rattache, et le cadre de la bulle ancrée à la bague
/// d'utilisation du Dock. Tout est exprimé en coordonnées globales AppKit (origine en bas à
/// gauche de l'écran principal, axe Y vers le haut).
enum SidePanelGeometry {

    /// Zone sensible : 100 pt de haut sur 20 pt de large, mesurée depuis le bord droit.
    static let hotZoneWidth: CGFloat = 20
    static let hotZoneHeight: CGFloat = 100

    /// Dimensions dictées par le contenu : le panneau porte la carte d'utilisation Claude
    /// (en-tête + deux lignes avec barre et pourcentage), qui a besoin de largeur pour tenir
    /// « Current session » et « Resets in 51 min » sur la même ligne. `ClaudeUsagePanelView`
    /// dérive ses propres marges de ce cadre.
    static let panelWidth: CGFloat = 320
    static let panelHeight: CGFloat = 190

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

// MARK: - Bulle ancrée à la bague

extension SidePanelGeometry {

    /// Pointe de la bulle : elle dépasse sous le corps et vise le centre de la bague.
    static let tailLength: CGFloat = 11
    static let tailWidth: CGFloat = 20

    /// Écart entre le haut de la bague et la pointe — assez petit pour que le curseur traverse
    /// sans que la bulle se referme, assez grand pour que les deux ne se touchent pas.
    static let tailGap: CGFloat = 8

    /// Marge minimale conservée avec les bords de l'écran quand la bague est près d'un coin.
    static let calloutScreenMargin: CGFloat = 10

    /// Cadre complet de la bulle, **pointe comprise** : le corps occupe le haut, la pointe les
    /// `tailLength` points du bas. La bulle est centrée sur la bague, puis ramenée dans l'écran
    /// si elle en sortait — c'est le seul cas où la pointe n'est plus au milieu du corps, et
    /// `tailCenterX(for:ringRect:)` s'en charge.
    static func calloutFrame(anchoredTo ringRect: NSRect, on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let height = panelHeight + tailLength

        let minX = visible.minX + calloutScreenMargin
        let maxX = max(minX, visible.maxX - panelWidth - calloutScreenMargin)
        let x = min(max(ringRect.midX - panelWidth / 2, minX), maxX)

        // La bulle se pose au-dessus de la bague ; si l'écran manque de hauteur au-dessus du
        // Dock, elle redescend juste sous la barre de menus plutôt que de passer dessous.
        let maxY = max(visible.minY, visible.maxY - height - calloutScreenMargin)
        let y = min(ringRect.maxY + tailGap, maxY)

        return NSRect(x: x, y: y, width: panelWidth, height: height)
    }

    /// Abscisse de la pointe dans le repère de la vue (origine au coin bas-gauche du cadre) :
    /// elle suit le centre de la bague, sans jamais mordre sur les coins arrondis.
    static func tailCenterX(for frame: NSRect, ringRect: NSRect) -> CGFloat {
        let inset = calloutCornerRadius + tailWidth / 2
        let raw = ringRect.midX - frame.minX
        return min(max(raw, inset), frame.width - inset)
    }

    /// Rayon des quatre coins de la bulle. Plus serré que celui du panneau de bord, qui vaut la
    /// moitié de sa largeur pour évaser la silhouette dans le bord de l'écran.
    static let calloutCornerRadius: CGFloat = 18
}

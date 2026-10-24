import AppKit

/// Géométrie du panneau latéral pour un écran donné : la zone sensible collée au coin supérieur
/// droit, le cadre du panneau qui s'y rattache, et le cadre de la bulle ancrée à l'une de ses
/// bagues. Tout est exprimé en coordonnées globales AppKit (origine en bas à gauche de l'écran
/// principal, axe Y vers le haut).
enum SidePanelGeometry {

    /// Zone sensible : 100 pt de haut sur 20 pt de large, mesurée depuis le bord droit.
    static let hotZoneWidth: CGFloat = 20
    static let hotZoneHeight: CGFloat = 100

    // MARK: - Bande de bagues

    /// Côté d'une case de bague — la bague elle-même plus le pourcentage posé dessous, voir
    /// `ClaudeUsageRingView`.
    static let ringTileSize: CGFloat = 60
    static let ringSpacing: CGFloat = 16
    static let ringInset: CGFloat = 14

    /// Rayon de la silhouette du panneau, partagé avec `SidePanelContentView` : c'est lui qui
    /// décide de la marge haute et basse, puisque les raccords concaves rognent la zone peinte
    /// près des deux extrémités.
    static let panelCornerRadius: CGFloat = 28

    /// Marge haute et basse de la pile de bagues : le rayon de la silhouette, plus de quoi ne pas
    /// raser le raccord. Sans elle, la première bague mord sur l'évasement et déborde du panneau.
    static let ringVerticalInset: CGFloat = panelCornerRadius + 10

    /// Une case de la bande : la marque qu'elle porte, et si une source de données l'alimente.
    /// Les bagues non branchées sont là pour la silhouette — anneau vide, marque en teinte
    /// neutre — en attendant que leur fournisseur soit raccordé.
    struct RingSlot: Equatable {
        let mark: UsageMarkPath
        let isConnected: Bool
    }

    /// Les bagues empilées, de haut en bas. Seule celle de Claude a une source aujourd'hui ;
    /// c'est aussi la seule à ouvrir la bulle de détail.
    static let ringSlots: [RingSlot] = [
        RingSlot(mark: .claude, isConnected: true),
        RingSlot(mark: .codex, isConnected: false),
        RingSlot(mark: .gemini, isConnected: false),
    ]

    static var ringCount: Int { ringSlots.count }

    /// Le panneau est désormais une bande étroite : il ne porte plus la carte d'utilisation mais
    /// seulement les bagues, la carte étant passée dans la bulle qui s'ouvre au survol.
    static let panelWidth: CGFloat = ringTileSize + 2 * ringInset

    /// Hauteur plancher de la bande : elle garde sa silhouette haute et élancée même avec une
    /// seule bague, les suivantes venant remplir la place déjà réservée. Au-delà, c'est le
    /// contenu qui commande.
    static let minimumPanelHeight: CGFloat = 400

    static var panelHeight: CGFloat {
        let content = 2 * ringVerticalInset
            + CGFloat(ringCount) * ringTileSize
            + CGFloat(max(0, ringCount - 1)) * ringSpacing
        return max(content, minimumPanelHeight)
    }

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
    /// marge. Le haut affleure de même le bord supérieur : c'est `frame`, pas `visibleFrame`, qui
    /// le donne — ce dernier s'arrête sous la barre de menus, plus bas encore sur un écran à
    /// encoche. La fenêtre est au niveau `.screenSaver` (voir `SidePanelWindow`), donc au-dessus
    /// de cette barre, et la zone sensible se mesure déjà depuis `frame.maxY`.
    static func panelFrame(on screen: NSScreen) -> NSRect {
        let top = screen.frame.maxY
        return NSRect(
            x: screen.frame.maxX - panelWidth,
            y: top - panelHeight,
            width: panelWidth,
            height: panelHeight
        )
    }
}

// MARK: - Bulle ancrée à une bague

extension SidePanelGeometry {

    /// Dimensions de la carte d'utilisation portée par la bulle : elle a besoin de largeur pour
    /// tenir « Current session » et « Resets in 51 min » sur la même ligne.
    static let calloutWidth: CGFloat = 320
    static let calloutHeight: CGFloat = 190

    /// Pointe de la bulle : elle dépasse sur le côté du corps et vise la bague.
    static let tailLength: CGFloat = 11
    static let tailWidth: CGFloat = 20

    /// Écart entre le bord de la bague et la pointe — assez petit pour que le curseur traverse
    /// sans que la bulle se referme, assez grand pour que les deux ne se touchent pas.
    static let tailGap: CGFloat = 8

    /// Marge minimale conservée avec les bords de l'écran quand la bague est près d'un coin.
    static let calloutScreenMargin: CGFloat = 10

    /// Rayon des quatre coins de la bulle. Plus serré que celui du panneau, qui s'évase dans le
    /// bord de l'écran.
    static let calloutCornerRadius: CGFloat = 18

    /// Bord du corps d'où sort la pointe. `.right` signifie que la bulle est posée **à gauche**
    /// de la bague et pointe vers elle, vers la droite — le cas de la bande accrochée au bord
    /// droit de l'écran.
    enum TailEdge: Equatable {
        case left
        case right
    }

    /// Ce que la vue a besoin pour dessiner sa silhouette : de quel bord sort la pointe, et à
    /// quelle hauteur dans son propre repère.
    struct Tail: Equatable {
        var edge: TailEdge
        var centerY: CGFloat
    }

    /// Cadre complet de la bulle, **pointe comprise**, et la pointe qui va avec.
    struct Callout: Equatable {
        var frame: NSRect
        var tail: Tail
    }

    /// Pose la bulle à côté de la bague : de préférence à sa gauche, comme dans la référence, et
    /// à sa droite quand l'écran manque de place de ce côté. Elle est centrée verticalement sur
    /// la bague, puis ramenée dans l'écran si elle en sortait — c'est le seul cas où la pointe
    /// n'est plus au milieu du corps.
    static func callout(anchoredTo ringRect: NSRect, on screen: NSScreen) -> Callout {
        let visible = screen.visibleFrame
        let width = calloutWidth + tailLength

        let minX = visible.minX + calloutScreenMargin
        let maxX = max(minX, visible.maxX - width - calloutScreenMargin)

        // À gauche de la bague tant qu'elle y tient entièrement ; sinon de l'autre côté.
        let leftX = ringRect.minX - tailGap - width
        let edge: TailEdge = leftX >= minX ? .right : .left
        let rawX = edge == .right ? leftX : ringRect.maxX + tailGap
        let x = min(max(rawX, minX), maxX)

        let minY = visible.minY + calloutScreenMargin
        let maxY = max(minY, visible.maxY - calloutHeight - calloutScreenMargin)
        let y = min(max(ringRect.midY - calloutHeight / 2, minY), maxY)

        let frame = NSRect(x: x, y: y, width: width, height: calloutHeight)
        return Callout(frame: frame, tail: Tail(edge: edge, centerY: tailCenterY(for: frame, ringRect: ringRect)))
    }

    /// Ordonnée de la pointe dans le repère de la vue (origine au coin bas-gauche du cadre) :
    /// elle suit le centre de la bague, sans jamais mordre sur les coins arrondis.
    private static func tailCenterY(for frame: NSRect, ringRect: NSRect) -> CGFloat {
        let inset = calloutCornerRadius + tailWidth / 2
        let raw = ringRect.midY - frame.minY
        return min(max(raw, inset), frame.height - inset)
    }
}

import AppKit

/// Contenu de la bande latérale : les bagues d'utilisation empilées, une par source. Une seule
/// est branchée aujourd'hui (Claude) ; les suivantes viendront s'ajouter ici sans que la
/// silhouette du panneau ni la bulle n'aient à changer.
///
/// La vue ne reçoit aucun événement de souris — la fenêtre du panneau laisse tout passer (voir
/// `SidePanelWindow`) — donc c'est `SidePanelController` qui décide, depuis la position globale
/// du curseur, quelle bague est survolée et le lui dit par `setHighlighted(_:)`.
final class ClaudeUsageRingStripView: NSView {

    private let rings: [ClaudeUsageRingView]

    override init(frame frameRect: NSRect) {
        rings = (0..<SidePanelGeometry.ringCount).map { _ in
            ClaudeUsageRingView(tileSize: SidePanelGeometry.ringTileSize)
        }
        super.init(frame: frameRect)
        wantsLayer = true
        rings.forEach(addSubview)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ state: ClaudeUsageState, animated: Bool) {
        // Une seule source pour l'instant : toutes les bagues montrent l'utilisation Claude.
        rings.forEach { $0.apply(state, animated: animated) }
    }

    /// Met en avant la bague survolée et laisse retomber les autres.
    func setHighlightedRing(_ index: Int?) {
        for (position, ring) in rings.enumerated() {
            ring.setHighlighted(position == index)
        }
    }

    /// Cadre d'une bague dans le repère de cette vue, `nil` hors des bornes — c'est ce que le
    /// contrôleur convertit en coordonnées écran pour ancrer la bulle.
    func ringFrame(at index: Int) -> NSRect? {
        guard rings.indices.contains(index) else { return nil }
        return rings[index].frame
    }

    var ringCount: Int { rings.count }

    override func layout() {
        super.layout()

        let tile = SidePanelGeometry.ringTileSize
        let spacing = SidePanelGeometry.ringSpacing

        // Empilées depuis le haut : la première bague est la plus proche de la barre de menus,
        // comme dans la référence.
        for (position, ring) in rings.enumerated() {
            let top = bounds.maxY - CGFloat(position) * (tile + spacing)
            ring.frame = NSRect(x: (bounds.width - tile) / 2, y: top - tile, width: tile, height: tile)
        }
    }
}

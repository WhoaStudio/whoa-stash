import AppKit

/// Contenu de la bande latérale : les bagues d'utilisation empilées, une par case déclarée dans
/// `SidePanelGeometry.ringSlots`. Celles qui n'ont pas encore de source restent vides, avec leur
/// marque en teinte neutre — elles ne sont pas alimentées par l'instantané Claude.
///
/// La vue ne reçoit aucun événement de souris — la fenêtre du panneau laisse tout passer (voir
/// `SidePanelWindow`) — donc c'est `SidePanelController` qui décide, depuis la position globale
/// du curseur, quelle bague est survolée et le lui dit par `setHighlighted(_:)`.
final class ClaudeUsageRingStripView: NSView {

    private let rings: [ClaudeUsageRingView]

    override init(frame frameRect: NSRect) {
        rings = SidePanelGeometry.ringSlots.map { slot in
            ClaudeUsageRingView(tileSize: SidePanelGeometry.ringTileSize, mark: slot.mark)
        }
        super.init(frame: frameRect)
        wantsLayer = true
        rings.forEach(addSubview)

        // Les cases sans source partent — et restent — sur un anneau vide.
        for (position, ring) in rings.enumerated() where !SidePanelGeometry.ringSlots[position].isConnected {
            ring.apply(.unavailable(reason: "Not connected"), animated: false)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ state: ClaudeUsageState, animated: Bool) {
        for (position, ring) in rings.enumerated() where SidePanelGeometry.ringSlots[position].isConnected {
            ring.apply(state, animated: animated)
        }
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
        let gaps = CGFloat(max(1, rings.count - 1))
        // Réparties sur toute la hauteur disponible plutôt que tassées en haut : la bande est
        // plus haute que ses bagues, et l'espace en trop se distribue entre elles. L'écart ne
        // descend jamais sous `ringSpacing`, qui reste le minimum lisible.
        let spacing = max(SidePanelGeometry.ringSpacing, (bounds.height - CGFloat(rings.count) * tile) / gaps)

        // Empilées depuis le haut : la première bague est la plus proche de la barre de menus,
        // comme dans la référence.
        for (position, ring) in rings.enumerated() {
            let top = bounds.maxY - CGFloat(position) * (tile + spacing)
            ring.frame = NSRect(x: (bounds.width - tile) / 2, y: top - tile, width: tile, height: tile)
        }
    }
}

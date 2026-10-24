import AppKit

/// Rangée des bagues d'utilisation, une par case déclarée dans `SidePanelGeometry.ringSlots`.
/// Celles qui n'ont pas encore de source restent vides, avec leur marque en teinte neutre —
/// elles ne sont pas alimentées par l'instantané Claude.
///
/// Les bagues sont alignées **horizontalement** depuis que le panneau est large : elles étaient
/// empilées du temps de la bande étroite d'une seule bague.
///
/// La vue ne gère pas le survol elle-même : c'est `SidePanelController` qui décide, depuis la
/// position globale du curseur, quelle bague est survolée et le lui dit par
/// `setHighlightedRing(_:)`. La fenêtre reçoit désormais les clics (la barre d'onglets en a
/// besoin), mais le suivi des bagues reste global — il doit aussi fonctionner pendant que le
/// curseur traverse la bulle, qui est une autre fenêtre.
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
        let spacing = SidePanelGeometry.ringSpacing

        // Le groupe est centré dans la largeur disponible, avec un écart fixe entre bagues : les
        // répartir sur toute la largeur les éloignerait trop les unes des autres sur un panneau
        // large, alors qu'elles forment une seule rangée à lire d'un coup.
        let total = CGFloat(rings.count) * tile + CGFloat(max(0, rings.count - 1)) * spacing
        var x = bounds.midX - total / 2
        let y = bounds.midY - tile / 2

        for ring in rings {
            ring.frame = NSRect(x: x, y: y, width: tile, height: tile)
            x += tile + spacing
        }
    }
}

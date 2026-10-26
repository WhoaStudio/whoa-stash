import AppKit

/// Contenu du panneau latéral : les bagues d'utilisation.
///
/// La bande n'a ni onglets ni semaine — ils appartiennent au panneau de l'encoche, qui a la
/// largeur et la permanence pour les porter. Ce qu'elle montre tient sur une seule vue, et
/// celle-ci existe pour que `SidePanelContentView` n'ait pas à mêler la silhouette et son contenu.
final class SidePanelStackView: NSView {

    private let ringStrip = ClaudeUsageRingStripView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        addSubview(ringStrip)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(usageState: ClaudeUsageState, animated: Bool) {
        ringStrip.apply(usageState, animated: animated)
    }

    func setHighlightedRing(_ index: Int?) {
        ringStrip.setHighlightedRing(index)
    }

    /// Cadre d'une bague dans le repère de cette vue.
    func ringFrame(at index: Int) -> NSRect? {
        guard let frame = ringStrip.ringFrame(at: index) else { return nil }
        return ringStrip.convert(frame, to: self)
    }

    var ringCount: Int { ringStrip.ringCount }

    override func layout() {
        super.layout()
        ringStrip.frame = bounds
    }
}

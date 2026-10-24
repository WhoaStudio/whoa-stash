import AppKit

/// Onglet Global : le contenu historique du panneau. La semaine en haut, les bagues d'utilisation
/// dessous.
///
/// Sert surtout à garder `SidePanelContentView` lisible maintenant qu'il arbitre trois onglets :
/// tout ce qui touche aux bagues passe par ici, et la vue de contenu ne fait plus que relayer.
final class NotchGlobalTabView: NSView {

    private let weekStrip = WeekStripView()
    private let ringStrip = ClaudeUsageRingStripView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        addSubview(weekStrip)
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

    /// Remet la bande de la semaine à la bonne date — appelé juste avant chaque apparition.
    func refreshWeek() {
        weekStrip.refresh()
    }

    /// Cadre d'une bague dans le repère de cette vue.
    func ringFrame(at index: Int) -> NSRect? {
        guard let frame = ringStrip.ringFrame(at: index) else { return nil }
        return ringStrip.convert(frame, to: self)
    }

    var ringCount: Int { ringStrip.ringCount }

    override func layout() {
        super.layout()

        let weekHeight = SidePanelGeometry.weekStripHeight
        weekStrip.frame = NSRect(
            x: bounds.minX,
            y: bounds.maxY - weekHeight,
            width: bounds.width,
            height: weekHeight
        )

        ringStrip.frame = NSRect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.width,
            height: max(0, weekStrip.frame.minY - SidePanelGeometry.contentSpacing - bounds.minY)
        )
    }
}

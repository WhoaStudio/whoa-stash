import AppKit

/// Bouton des Préférences, en haut à droite du panneau de l'encoche. Un simple glyphe qui
/// s'éclaircit au survol.
final class NotchGearButtonView: NSView {

    var onClick: (() -> Void)?

    private let iconView = NSImageView()
    private var palette = OverlayPalette.resolved(for: .currentDrawing())
    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        let configuration = NSImage.SymbolConfiguration(
            pointSize: TabBarMetrics.iconSize,
            weight: .medium
        )
        iconView.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")?
            .withSymbolConfiguration(configuration)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        applyTint()
    }

    func applyPalette(_ palette: OverlayPalette) {
        self.palette = palette
        applyTint()
    }

    private func applyTint() {
        iconView.contentTintColor = isHovered ? palette.tabActiveContent : palette.tabInactiveContent
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        applyTint()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        applyTint()
    }

    override func layout() {
        super.layout()
        let icon = TabBarMetrics.iconSize
        iconView.frame = NSRect(
            x: bounds.midX - icon / 2,
            y: bounds.midY - icon / 2,
            width: icon,
            height: icon
        )
    }

    /// Même raison que pour une bulle : le glyphe est une sous-vue, et c'est lui que le clic
    /// atteindrait.
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard bounds.contains(location) else { return }
        onClick?()
    }
}

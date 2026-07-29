import AppKit

/// Une icône de l'extension du Dock : hover et clic animés au ressort (comme le vrai Dock),
/// réutilise `CALayer.springAnimate` déjà utilisé par le slider et l'overlay de luminosité.
final class DockExtensionIconView: NSView {

    let slot: ResolvedDockSlot

    var onClick: ((ResolvedDockSlot) -> Void)?
    /// Laissé en place pour un futur menu contextuel — non implémenté pour l'instant.
    var onRightClick: ((ResolvedDockSlot) -> Void)?

    private let imageLayer = CALayer()
    private var trackingArea: NSTrackingArea?

    /// Les icônes du vrai Dock ne remplissent pas leur case à 100% — les images d'app intègrent
    /// une marge optique. Sans cet inset, nos icônes rendent visiblement plus grandes que
    /// celles du Dock à côté.
    private let iconInsetRatio: CGFloat = 0.09

    init(slot: ResolvedDockSlot, tileSize: CGFloat) {
        self.slot = slot
        super.init(frame: NSRect(x: 0, y: 0, width: tileSize, height: tileSize))
        wantsLayer = true
        toolTip = slot.name

        imageLayer.contents = slot.icon
        imageLayer.contentsGravity = .resizeAspect
        layer?.addSublayer(imageLayer)
        layoutImageLayer()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layoutImageLayer()
    }

    private func layoutImageLayer() {
        imageLayer.frame = bounds.insetBy(dx: bounds.width * iconInsetRatio, dy: bounds.height * iconInsetRatio)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        imageLayer.springAnimate(keyPath: "transform.scale", to: 1.15, preset: .snappy)
    }

    override func mouseExited(with event: NSEvent) {
        imageLayer.springAnimate(keyPath: "transform.scale", to: 1.0, preset: .snappy)
    }

    override func mouseDown(with event: NSEvent) {
        imageLayer.springAnimate(keyPath: "transform.scale", to: 0.88, preset: .snappy)
    }

    override func mouseUp(with event: NSEvent) {
        let insideAfterRelease = bounds.contains(convert(event.locationInWindow, from: nil))
        imageLayer.springAnimate(keyPath: "transform.scale", to: insideAfterRelease ? 1.15 : 1.0, preset: .snappy)
        if insideAfterRelease {
            onClick?(slot)
        }
    }

    override func rightMouseUp(with event: NSEvent) {
        onRightClick?(slot)
    }
}

import AppKit

/// Bouton circulaire à droite de la barre, sur le même fond plein que la pilule et que le
/// panneau de l'encoche (`OverlayPalette.panelBackground`). Il ne porte que l'icône soleil :
/// la valeur, elle, s'affiche hors de la bande dans `BrightnessValueBubbleView` le temps du
/// réglage, et non plus à la place de l'icône.
final class SunButtonView: NSView {

    var onTap: (() -> Void)?

    private let backgroundLayer = CALayer()
    private let strokeLayer = CAShapeLayer()
    private let iconLayer = CALayer()

    private var palette: OverlayPalette

    /// Rect de l'icône, centré dans le bouton.
    private let contentSize = CGSize(width: 30, height: 18)

    init(palette: OverlayPalette) {
        self.palette = palette
        super.init(frame: .zero)
        wantsLayer = true
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // zPosition explicite pour tout : l'ordre d'insertion des sous-calques suffirait
    // aujourd'hui, mais le stacking de cette vue a déjà été cassé une fois par un calque
    // qu'AppKit resynchronisait à sa guise. zPosition le fige, quoi qu'il arrive ensuite.
    private enum Depth {
        static let background: CGFloat = 0
        static let stroke: CGFloat = 1
        static let icon: CGFloat = 2
    }

    private func setUp() {
        backgroundLayer.zPosition = Depth.background
        layer?.addSublayer(backgroundLayer)

        strokeLayer.fillColor = nil
        strokeLayer.lineWidth = 1
        strokeLayer.zPosition = Depth.stroke
        layer?.addSublayer(strokeLayer)

        iconLayer.contentsGravity = .resizeAspect
        iconLayer.shadowOffset = .zero
        iconLayer.zPosition = Depth.icon
        layer?.addSublayer(iconLayer)

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)

        apply(palette: palette)
    }

    override func layout() {
        super.layout()

        let radius = bounds.width / 2

        backgroundLayer.frame = bounds
        backgroundLayer.cornerRadius = radius

        strokeLayer.path = CGPath(ellipseIn: bounds.insetBy(dx: 0.5, dy: 0.5), transform: nil)

        let contentFrame = CGRect(
            x: (bounds.width - contentSize.width) / 2,
            y: (bounds.height - contentSize.height) / 2,
            width: contentSize.width,
            height: contentSize.height
        )
        iconLayer.frame = contentFrame
    }

    func apply(palette: OverlayPalette) {
        self.palette = palette
        backgroundLayer.backgroundColor = palette.panelBackground
        strokeLayer.strokeColor = palette.strokeColor
        iconLayer.contents = symbolImage(tint: palette.buttonSymbolColor)
    }

    private func symbolImage(tint: NSColor) -> CGImage? {
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let colorConfig = NSImage.SymbolConfiguration(paletteColors: [tint])
        let config = sizeConfig.applying(colorConfig)

        guard let image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return nil }

        // Les images de symboles système sont marquées "template" par défaut : converties
        // telles quelles en CGImage, on récupère un masque monochrome qui ignore la couleur
        // de palette qu'on vient de configurer. On désactive explicitement le template pour
        // que la couleur choisie soit bien celle qui se retrouve dans le bitmap.
        image.isTemplate = false

        var rect = NSRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.springAnimate(keyPath: "transform.scale", to: 1.08)
        layer?.springAnimate(keyPath: "shadowColor", to: palette.buttonGlowColor)
        layer?.springAnimate(keyPath: "shadowRadius", to: 6)
        layer?.springAnimate(keyPath: "shadowOpacity", to: 1)
    }

    override func mouseExited(with event: NSEvent) {
        layer?.springAnimate(keyPath: "transform.scale", to: 1.0)
        layer?.springAnimate(keyPath: "shadowOpacity", to: 0)
    }

    override func mouseDown(with event: NSEvent) {
        onTap?()
    }
}

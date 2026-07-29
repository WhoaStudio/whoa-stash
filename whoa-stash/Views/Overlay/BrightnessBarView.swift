import AppKit

/// Barre verticale en forme de pilule : fond flouté (`NSVisualEffectView`), teinte et
/// liseré adaptés au thème, contenant les graduations indépendantes de `BrightnessTicksView`.
final class BrightnessBarView: NSView {

    let ticksView: BrightnessTicksView

    private let visualEffectView = NSVisualEffectView()
    private let tintLayer = CALayer()
    private let strokeLayer = CAShapeLayer()

    private let tickInset = NSEdgeInsets(top: 16, left: 7, bottom: 16, right: 7)

    init(tickCount: Int, palette: OverlayPalette) {
        ticksView = BrightnessTicksView(tickCount: tickCount, palette: palette)
        super.init(frame: .zero)
        wantsLayer = true
        setUp(palette: palette)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Même remarque que dans SunButtonView : NSView (addSubview) et CALayer (addSublayer)
    // mélangés comme frères n'ont pas d'ordre garanti. zPosition fige le stacking.
    private enum Depth {
        static let blur: CGFloat = 0
        static let tint: CGFloat = 1
        static let stroke: CGFloat = 2
        static let ticks: CGFloat = 3
    }

    private func setUp(palette: OverlayPalette) {
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        addSubview(visualEffectView)
        visualEffectView.layer?.zPosition = Depth.blur

        tintLayer.zPosition = Depth.tint
        layer?.addSublayer(tintLayer)

        strokeLayer.fillColor = nil
        strokeLayer.lineWidth = 1
        strokeLayer.zPosition = Depth.stroke
        layer?.addSublayer(strokeLayer)

        addSubview(ticksView)
        ticksView.layer?.zPosition = Depth.ticks

        apply(palette: palette)
    }

    override func layout() {
        super.layout()

        visualEffectView.frame = bounds
        let radius = bounds.width / 2
        visualEffectView.layer?.cornerRadius = radius
        visualEffectView.layer?.masksToBounds = true

        tintLayer.frame = bounds
        tintLayer.cornerRadius = radius

        strokeLayer.path = CGPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )

        ticksView.frame = NSRect(
            x: tickInset.left,
            y: tickInset.bottom,
            width: bounds.width - tickInset.left - tickInset.right,
            height: bounds.height - tickInset.top - tickInset.bottom
        )
    }

    func apply(palette: OverlayPalette) {
        visualEffectView.material = palette.backgroundMaterial
        tintLayer.backgroundColor = palette.backgroundTint
        strokeLayer.strokeColor = palette.strokeColor
        ticksView.apply(palette: palette)
    }

    func setActiveTickCount(_ count: Int, animated: Bool) {
        ticksView.setActiveCount(count, animated: animated)
    }
}

import AppKit

/// Vue racine de l'overlay : assemble `BrightnessBarView` et `SunButtonView`, pilote
/// l'animation d'apparition/disparition et retranscrit le thème effectif (clair/sombre)
/// vers ses enfants à chaque changement d'apparence.
final class BrightnessView: NSView {

    let barView: BrightnessBarView
    let sunButton: SunButtonView

    /// Le scroll trackpad n'est exposé nulle part au niveau fenêtre par AppKit :
    /// on le capte directement ici, sur la vue qui reçoit réellement l'événement.
    var onScroll: ((CGFloat) -> Void)?

    private let barInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 0)
    private let barWidth: CGFloat = 40
    private let buttonSize: CGFloat = 44
    private let buttonSpacing: CGFloat = 10

    init(tickCount: Int, initialPalette: OverlayPalette) {
        barView = BrightnessBarView(tickCount: tickCount, palette: initialPalette)
        sunButton = SunButtonView(palette: initialPalette)
        super.init(frame: .zero)
        wantsLayer = true
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        addSubview(barView)
        addSubview(sunButton)

        // État de départ pour l'entrée : invisible, légèrement rétracté vers la gauche.
        layer?.opacity = 0
        layer?.transform = Self.hiddenTransform
    }

    override func layout() {
        super.layout()

        barView.frame = NSRect(
            x: barInsets.left,
            y: barInsets.bottom,
            width: barWidth,
            height: bounds.height - barInsets.top - barInsets.bottom
        )

        sunButton.frame = NSRect(
            x: barView.frame.maxX + buttonSpacing,
            y: (bounds.height - buttonSize) / 2,
            width: buttonSize,
            height: buttonSize
        )
    }

    private static var hiddenTransform: CATransform3D {
        CATransform3DConcat(CATransform3DMakeScale(0.95, 0.95, 1), CATransform3DMakeTranslation(-14, 0, 0))
    }

    func setVisible(_ visible: Bool) {
        layer?.springAnimate(keyPath: "opacity", to: visible ? 1 : 0, preset: .gentle)
        layer?.springAnimate(
            keyPath: "transform",
            to: NSValue(caTransform3D: visible ? CATransform3DIdentity : Self.hiddenTransform),
            preset: .gentle
        )
    }

    func updateBrightness(activeTickCount: Int, animated: Bool) {
        barView.setActiveTickCount(activeTickCount, animated: animated)
    }

    func showPercent(_ percent: Int) {
        sunButton.showPercent(percent)
    }

    func applyPalette(_ palette: OverlayPalette) {
        barView.apply(palette: palette)
        sunButton.apply(palette: palette)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPalette(OverlayPalette.resolved(for: effectiveAppearance))
    }

    override func scrollWheel(with event: NSEvent) {
        onScroll?(event.scrollingDeltaY)
    }
}

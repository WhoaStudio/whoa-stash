import AppKit

/// Vue racine de l'overlay : une bande accrochée à un bord de l'écran, de la même matière que
/// le panneau latéral — même largeur, même hauteur, même silhouette évasée dans le bord, même
/// fond plein et même filet (`PanelGeometry`). Posées sur les deux bords du même écran, les deux
/// bandes se lisent comme deux images l'une de l'autre.
///
/// Assemble `BrightnessBarView` et `SunButtonView` dans la boîte de contenu de la bande, pilote
/// l'animation d'apparition/disparition et retranscrit le thème effectif (clair/sombre) vers ses
/// enfants à chaque changement d'apparence.
final class BrightnessView: NSView {

    let barView: BrightnessBarView
    let sunButton: SunButtonView

    /// Le scroll trackpad n'est exposé nulle part au niveau fenêtre par AppKit :
    /// on le capte directement ici, sur la vue qui reçoit réellement l'événement.
    var onScroll: ((CGFloat) -> Void)?

    /// Bord d'accroche de la bande, relayé par `BrightnessOverlayController` depuis les
    /// Préférences : c'est lui qui décide de quel côté la silhouette s'évase.
    var edge: EdgePosition = .left {
        didSet {
            guard edge != oldValue else { return }
            needsLayout = true
        }
    }

    private let backgroundLayer = CAShapeLayer()
    private let strokeLayer = CAShapeLayer()

    private let barWidth: CGFloat = 40
    private let buttonSize: CGFloat = 44
    private let buttonSpacing: CGFloat = 10

    // Même remarque que dans BrightnessBarView : NSView (addSubview) et CALayer (addSublayer)
    // mélangés comme frères n'ont pas d'ordre garanti. zPosition fige le stacking.
    private enum Depth {
        static let background: CGFloat = -2
        static let stroke: CGFloat = -1
    }

    init(tickCount: Int, initialPalette: OverlayPalette) {
        barView = BrightnessBarView(tickCount: tickCount, palette: initialPalette)
        sunButton = SunButtonView(palette: initialPalette)
        super.init(frame: .zero)
        wantsLayer = true
        setUp(palette: initialPalette)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp(palette: OverlayPalette) {
        // Fond plein plutôt qu'un `NSVisualEffectView`, comme le panneau latéral : le matériau
        // laissait remonter le fond d'écran et délavait la surface en gris.
        backgroundLayer.zPosition = Depth.background
        layer?.addSublayer(backgroundLayer)

        strokeLayer.fillColor = nil
        strokeLayer.lineWidth = PanelGeometry.strokeWidth
        strokeLayer.zPosition = Depth.stroke
        layer?.addSublayer(strokeLayer)

        addSubview(barView)
        addSubview(sunButton)

        applyPalette(palette)

        // État de départ pour l'entrée : invisible, légèrement rétracté vers la gauche.
        layer?.opacity = 0
        layer?.transform = Self.hiddenTransform
    }

    override func layout() {
        super.layout()

        let path = PanelGeometry.silhouette(in: bounds, anchoredTo: edge)
        backgroundLayer.frame = bounds
        backgroundLayer.path = path
        strokeLayer.frame = bounds
        // Exactement le même chemin que le fond, tracé centré sur la frontière — voir
        // `SidePanelContentView` pour pourquoi aucun `insetBy` n'est appliqué ici.
        strokeLayer.path = path

        // Boîte de contenu : tout ce qui est peint reste à l'intérieur de la ligne où le bord
        // se relève vers le bord de l'écran pour former l'évasement.
        let box = bounds.insetBy(
            dx: PanelGeometry.contentHorizontalInset,
            dy: PanelGeometry.contentVerticalInset
        )

        // La barre et le soleil restent groupés et centrés dans la boîte : la bande est bien plus
        // large qu'eux, et les coller à un bord les ferait flotter de travers.
        let groupWidth = barWidth + buttonSpacing + buttonSize
        let groupX = box.minX + (box.width - groupWidth) / 2

        barView.frame = NSRect(x: groupX, y: box.minY, width: barWidth, height: box.height)

        sunButton.frame = NSRect(
            x: barView.frame.maxX + buttonSpacing,
            y: box.midY - buttonSize / 2,
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
        backgroundLayer.fillColor = palette.panelBackground
        strokeLayer.strokeColor = palette.strokeColor
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

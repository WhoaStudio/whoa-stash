import AppKit

/// Bulle de valeur : une pilule posée à côté de la bande de luminosité, hors de sa silhouette,
/// qui porte le pourcentage courant. Même matière que la barre et le bouton soleil
/// (`OverlayPalette.panelBackground` et son filet) — c'est la même surface, détachée.
///
/// Elle n'existe que pendant le réglage : la bande seule n'affiche aucun chiffre, et la bulle
/// n'apparaît qu'au moment où la luminosité bouge, puis s'efface d'elle-même peu après le
/// dernier cran. Chaque nouvelle valeur repousse ce retrait, pour qu'un réglage continu ne la
/// fasse pas clignoter.
final class BrightnessValueBubbleView: NSView {

    private let backgroundLayer = CALayer()
    private let strokeLayer = CAShapeLayer()
    private let valueLayer = CATextLayer()

    private var palette: OverlayPalette
    private var isShowing = false
    private var hideWorkItem: DispatchWorkItem?

    /// Délai après le dernier changement avant que la bulle ne s'efface — celui que le
    /// pourcentage avait quand il vivait dans le bouton soleil.
    private let hideDelay: TimeInterval = 0.9

    /// Décalage d'entrée, posé par `BrightnessView` : la bulle glisse depuis la bande, donc le
    /// sens dépend du bord auquel celle-ci est accrochée.
    var entryOffset: CGFloat = -12 {
        didSet {
            guard entryOffset != oldValue, !isShowing else { return }
            applyHiddenState()
        }
    }

    /// Taille de la pilule. Fixe : un chiffre de plus ou de moins ne doit pas la faire respirer
    /// pendant qu'on règle la luminosité.
    var intrinsicSize: CGSize { CGSize(width: 54, height: 32) }

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

    // Même remarque que dans SunButtonView : NSView et CALayer mélangés comme frères n'ont pas
    // d'ordre garanti. zPosition fige le stacking.
    private enum Depth {
        static let background: CGFloat = 0
        static let stroke: CGFloat = 1
        static let value: CGFloat = 2
    }

    private func setUp() {
        backgroundLayer.zPosition = Depth.background
        layer?.addSublayer(backgroundLayer)

        strokeLayer.fillColor = nil
        strokeLayer.lineWidth = 1
        strokeLayer.zPosition = Depth.stroke
        layer?.addSublayer(strokeLayer)

        valueLayer.alignmentMode = .center
        valueLayer.isWrapped = false
        valueLayer.truncationMode = .none
        valueLayer.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        valueLayer.fontSize = 15
        valueLayer.contentsScale = window?.backingScaleFactor ?? 2
        valueLayer.zPosition = Depth.value
        layer?.addSublayer(valueLayer)

        applyHiddenState()
        apply(palette: palette)
    }

    override func layout() {
        super.layout()

        backgroundLayer.frame = bounds
        backgroundLayer.cornerRadius = bounds.height / 2

        strokeLayer.path = CGPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            cornerWidth: bounds.height / 2,
            cornerHeight: bounds.height / 2,
            transform: nil
        )

        // Le texte est centré sur la hauteur de la pilule : `CATextLayer` dessine depuis le haut
        // de son cadre, donc c'est le cadre qu'on centre, pas la ligne de base.
        let lineHeight = valueLayer.fontSize * 1.2
        valueLayer.frame = CGRect(
            x: 0,
            y: (bounds.height - lineHeight) / 2,
            width: bounds.width,
            height: lineHeight
        )
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        valueLayer.contentsScale = window?.backingScaleFactor ?? 2
    }

    func apply(palette: OverlayPalette) {
        self.palette = palette
        backgroundLayer.backgroundColor = palette.panelBackground
        strokeLayer.strokeColor = palette.strokeColor
        valueLayer.foregroundColor = palette.buttonSymbolColor.cgColor
    }

    /// Affiche la valeur et repousse le retrait. Appelée à chaque cran franchi.
    func show(percent: Int) {
        valueLayer.string = "\(percent)"

        if !isShowing {
            isShowing = true
            layer?.springAnimate(keyPath: "opacity", to: 1)
            layer?.springAnimate(keyPath: "transform", to: NSValue(caTransform3D: CATransform3DIdentity))
        }

        scheduleHide()
    }

    private func scheduleHide() {
        hideWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isShowing else { return }
            self.isShowing = false
            self.layer?.springAnimate(keyPath: "opacity", to: 0)
            self.layer?.springAnimate(keyPath: "transform", to: NSValue(caTransform3D: self.hiddenTransform))
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + hideDelay, execute: item)
    }

    /// État de repos : effacée et rentrée vers la bande, prête à en ressortir.
    private func applyHiddenState() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.opacity = 0
        layer?.transform = hiddenTransform
        CATransaction.commit()
    }

    private var hiddenTransform: CATransform3D {
        CATransform3DConcat(
            CATransform3DMakeScale(0.9, 0.9, 1),
            CATransform3DMakeTranslation(entryOffset, 0, 0)
        )
    }
}

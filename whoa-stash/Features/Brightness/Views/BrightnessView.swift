import AppKit

/// Vue racine de l'overlay : une bande accrochée à un bord de l'écran, de la même matière que
/// le panneau latéral — même largeur, même hauteur, même silhouette évasée dans le bord, même
/// fond plein et même filet (`PanelGeometry`). Posées sur les deux bords du même écran, les deux
/// bandes se lisent comme deux images l'une de l'autre.
///
/// Assemble `BrightnessBarView` et `SunButtonView` dans la boîte de contenu de la bande, pilote
/// son dépliage et retranscrit le thème effectif (clair/sombre) vers ses enfants à chaque
/// changement d'apparence.
///
/// Elle se déplie depuis son bord comme la bande de bagues et le panneau de l'encoche, du même
/// geste et par le même moteur (`PanelFold`) : rien ne se déplace, c'est la silhouette qui passe
/// de la poignée à la bande entière. Comme la bande de bagues — et contrairement à l'encoche,
/// qui reste à l'écran repliée — elle s'efface tout entière, puisque rien ne doit rester sur le
/// bord entre deux survols.
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
    private let contentMask = CAShapeLayer()

    /// La barre et le soleil vivent dans un conteneur à part pour n'avoir qu'un masque à piloter
    /// pendant le dépliage. Masquer le calque de la vue elle-même rognerait aussi le filet, qui
    /// est tracé centré sur la frontière et y perdrait la moitié de son épaisseur.
    private let contentContainer = NSView()

    private(set) var isExpanded = false

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
        // Clic droit : le menu partagé par tous les panneaux de l'overlay. Posé ici plutôt que
        // sur chaque enfant — AppKit remonte la chaîne des responders jusqu'à la première vue
        // qui porte un menu.
        menu = OverlayContextMenu.shared.menu

        // Fond plein plutôt qu'un `NSVisualEffectView`, comme le panneau latéral : le matériau
        // laissait remonter le fond d'écran et délavait la surface en gris.
        backgroundLayer.zPosition = Depth.background
        layer?.addSublayer(backgroundLayer)

        strokeLayer.fillColor = nil
        strokeLayer.lineWidth = PanelGeometry.strokeWidth
        strokeLayer.zPosition = Depth.stroke
        layer?.addSublayer(strokeLayer)

        contentContainer.wantsLayer = true
        // Le contenu est découpé par la silhouette elle-même : pendant le dépliage il ne doit
        // rien dépasser de la forme, qui est encore plus étroite que lui.
        contentContainer.layer?.mask = contentMask
        addSubview(contentContainer)

        contentContainer.addSubview(barView)
        contentContainer.addSubview(sunButton)

        applyPalette(palette)

        // État de départ pour l'entrée : repliée et effacée. La silhouette, elle, est posée par
        // `layout()`, qui est le premier à connaître le cadre.
        layer?.opacity = 0
    }

    override func layout() {
        super.layout()

        // La silhouette est reposée dans l'état courant : la mise en page suit un changement de
        // bord, de taille ou d'écran, qui ne doit ni rejouer le dépliage ni laisser le chemin au
        // cadre précédent. Le fond et le filet reçoivent exactement le même chemin, tracé centré
        // sur la frontière — voir `SidePanelContentView` pour pourquoi aucun `insetBy` n'est
        // appliqué ici.
        applyShape(expanded: isExpanded, animated: false)

        contentContainer.frame = bounds

        // Boîte de contenu : tout ce qui est peint reste à l'intérieur de la ligne où le bord
        // se relève vers le bord de l'écran pour former l'évasement.
        let box = bounds.insetBy(
            dx: PanelGeometry.contentInsetAcrossAnchor,
            dy: PanelGeometry.contentInsetAlongAnchor
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

    // MARK: - Dépliage

    /// Les deux états, tirés de la même recette que les autres panneaux de l'overlay
    /// (`PanelGeometry.silhouette`), ici suspendue au bord configuré. Seuls la taille et les
    /// rayons les distinguent, donc les deux chemins ont le même nombre de segments dans le même
    /// ordre — c'est cette identité de structure qui rend le dépliage animable d'un seul
    /// `CASpringAnimation` sur `path`.

    private func collapsedPath() -> CGPath {
        PanelGeometry.silhouette(
            in: bounds,
            anchoredTo: PanelGeometry.Anchor(edge),
            size: PanelGeometry.collapsedHandleSize,
            shoulderRadius: PanelGeometry.collapsedShoulderRadius,
            farRadius: PanelGeometry.collapsedFarRadius
        )
    }

    private func expandedPath() -> CGPath {
        PanelGeometry.silhouette(in: bounds, anchoredTo: PanelGeometry.Anchor(edge))
    }

    /// Replie la bande sans animation et l'efface — à appeler avant d'afficher la fenêtre, pour
    /// que la première image montrée soit déjà le début du dépliage et non la bande en place.
    func prepareForReveal() {
        isExpanded = false
        // La mise en page est vidée tout de suite : sans cela la silhouette repliée serait posée
        // dans la même transaction que le dépliage, qui partirait alors du chemin précédent.
        layoutSubtreeIfNeeded()
        applyShape(expanded: false, animated: false)
    }

    /// Déplie ou replie la bande. `completion` est appelée une fois le ressort stabilisé, pour
    /// que le contrôleur puisse retirer la fenêtre.
    func setVisible(_ visible: Bool, completion: (() -> Void)? = nil) {
        guard visible != isExpanded else {
            completion?()
            return
        }
        isExpanded = visible
        applyShape(expanded: visible, animated: true, completion: completion)
    }

    private func applyShape(expanded: Bool, animated: Bool, completion: (() -> Void)? = nil) {
        guard bounds.width > 0, bounds.height > 0 else {
            completion?()
            return
        }

        // C'est tout le calque de la vue qui s'efface, filet et fond compris, et son fondu suit
        // le ressort du dépliage (`dissolving`) : sur un fondu court, la bande aurait disparu
        // avant d'avoir fini de se replier et le geste passerait inaperçu.
        PanelFold.apply(
            path: expanded ? expandedPath() : collapsedPath(),
            to: [backgroundLayer, strokeLayer, contentMask],
            in: bounds,
            dissolving: layer.map { [$0] } ?? [],
            to: expanded ? 1 : 0,
            animated: animated,
            completion: completion
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

import AppKit

/// Contenu du panneau latéral : une surface quasi opaque accrochée au bord droit de l'écran,
/// arrondie du côté intérieur et évasée dans le bord.
///
/// Porte les bagues d'utilisation (`SidePanelStackView`). La carte détaillée d'une bague, elle,
/// vit dans la bulle qui s'ouvre à son survol (`UsageCalloutWindow`).
///
/// Ni onglets ni semaine ici : ils appartiennent au panneau de l'encoche. La bande n'est à l'écran
/// que le temps d'un survol et ne reçoit aucun clic, deux raisons pour lesquelles une rangée
/// d'onglets y serait à la fois peu atteignable et coûteuse — il faudrait lui ouvrir les
/// événements souris.
///
/// Porte aussi l'animation d'entrée/sortie (glissement depuis le bord droit + fondu), appliquée
/// à son propre calque.
///
/// Mise en page entièrement en frames, comme le reste de l'overlay (`BrightnessBarView`) —
/// pas de contraintes Auto Layout.
final class SidePanelContentView: NSView {

    private let backgroundLayer = CAShapeLayer()
    private let strokeLayer = CAShapeLayer()

    private let stack = SidePanelStackView()

    /// Rayon unique de toute la silhouette : il vaut à la fois pour les deux coins convexes
    /// (côté intérieur) et pour les deux raccords concaves qui évasent le panneau dans le bord de
    /// l'écran. À `largeur / 2`, les deux arcs se rejoignent tangentiellement sans segment droit
    /// entre eux — c'est la proportion de la référence.
    private let cornerRadius = SidePanelGeometry.panelCornerRadius

    /// Durée du fondu seul : le glissement, lui, est porté par un ressort et dure le temps que
    /// met celui-ci à se stabiliser.
    private let fadeDuration: TimeInterval = 0.22

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        // Fond plein plutôt qu'un `NSVisualEffectView` : le matériau laissait remonter le fond
        // d'écran et délavait le panneau en gris, alors qu'il doit rester franchement sombre.
        layer?.addSublayer(backgroundLayer)

        strokeLayer.fillColor = nil
        strokeLayer.lineWidth = PanelGeometry.strokeWidth
        layer?.addSublayer(strokeLayer)

        addSubview(stack)

        // Aucune ombre portée : le panneau se détache par sa propre teinte et son filet, et la
        // fenêtre est elle aussi sans ombre (`SidePanelWindow`).
        layer?.masksToBounds = false

        applyPalette()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPalette()
    }

    private func applyPalette() {
        let palette = OverlayPalette.resolved(for: effectiveAppearance)
        backgroundLayer.fillColor = palette.panelBackground
        strokeLayer.strokeColor = palette.strokeColor
    }

    /// Relayé par `SidePanelWindow` depuis le modèle de vue partagé avec la bulle : les deux
    /// surfaces montrent toujours le même instantané.
    func apply(usageState: ClaudeUsageState, animated: Bool) {
        stack.apply(usageState: usageState, animated: animated)
    }

    /// Met en avant la bague survolée — le contrôleur la désigne depuis la position du curseur.
    func setHighlightedRing(_ index: Int?) {
        stack.setHighlightedRing(index)
    }

    /// Cadre d'une bague dans le repère de cette vue : `SidePanelWindow` le convertit en
    /// coordonnées écran pour que la bulle sache où pointer.
    func ringFrame(at index: Int) -> NSRect? {
        guard let frame = stack.ringFrame(at: index) else { return nil }
        return stack.convert(frame, to: self)
    }

    var ringCount: Int { stack.ringCount }

    override func layout() {
        super.layout()

        let path = PanelGeometry.silhouette(in: bounds, anchoredTo: .right, cornerRadius: cornerRadius)
        backgroundLayer.frame = bounds
        backgroundLayer.path = path
        strokeLayer.frame = bounds
        // Exactement le même chemin que le fond, tracé centré sur la frontière : un `insetBy`
        // uniforme ferait *grandir* le rayon concave là où il rétrécit les rayons convexes, ce qui
        // décollerait la bordure du fond précisément au niveau des raccords.
        strokeLayer.path = path

        // Boîte de contenu : tout ce qui est peint reste sous la ligne où le bord supérieur se
        // relève vers le bord de l'écran pour former l'évasement (voir `PanelGeometry.silhouette`).
        let box = bounds.insetBy(
            dx: SidePanelGeometry.contentHorizontalInset,
            dy: SidePanelGeometry.contentVerticalInset
        )

        stack.frame = box
    }

    // MARK: - Animation

    /// Amplitude du glissement : la bande vient de derrière le bord droit de l'écran.
    private var revealOffset: CGFloat { bounds.width }

    /// Place le contenu à son point de départ, complètement transparent — à appeler avant
    /// d'afficher la fenêtre pour que la première image montrée soit déjà le début du glissement
    /// et non le panneau en place.
    func prepareForReveal() {
        guard let layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Les deux axes sont réinitialisés : une même fenêtre passe de la carte de bord à la
        // bulle, et le décalage de la silhouette précédente resterait sinon appliqué.
        layer.setValue(revealOffset, forKeyPath: "transform.translation.x")
        layer.opacity = 0
        CATransaction.commit()
    }

    func animateIn() {
        guard let layer else { return }
        layer.springAnimate(keyPath: "transform.translation.x", to: CGFloat(0), preset: .gentle)
        animateOpacity(to: 1)
    }

    func animateOut(completion: @escaping () -> Void) {
        guard let layer else {
            completion()
            return
        }
        layer.springAnimate(keyPath: "transform.translation.x", to: revealOffset, preset: .gentle, completion: completion)
        animateOpacity(to: 0)
    }

    private func animateOpacity(to value: Float) {
        guard let layer else { return }

        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = layer.presentation()?.opacity ?? layer.opacity
        animation.toValue = value
        animation.duration = fadeDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        layer.opacity = value
        layer.add(animation, forKey: "opacity")
    }
}

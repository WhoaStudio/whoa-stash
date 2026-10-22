import AppKit

/// Contenu du panneau latéral : une colonne quasi opaque accrochée au bord droit de l'écran,
/// arrondie uniquement du côté intérieur, avec un texte de test centré. Porte aussi l'animation
/// d'entrée/sortie (glissement depuis le bord droit + fondu), appliquée à son propre calque.
///
/// Mise en page entièrement en frames, comme le reste de l'overlay (`DockExtensionContentView`,
/// `BrightnessBarView`) — pas de contraintes Auto Layout.
final class SidePanelContentView: NSView {

    private let backgroundLayer = CAShapeLayer()
    private let strokeLayer = CAShapeLayer()
    private let label = NSTextField(labelWithString: "[test text]")

    /// Rayon unique de toute la silhouette : il vaut à la fois pour les deux coins convexes
    /// (côté intérieur) et pour les deux raccords concaves qui évasent le panneau dans le bord de
    /// l'écran. À `largeur / 2`, les deux arcs se rejoignent tangentiellement sans segment droit
    /// entre eux — c'est la proportion de la référence.
    private let cornerRadius: CGFloat = 50

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
        strokeLayer.lineWidth = 1
        layer?.addSublayer(strokeLayer)

        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.alignment = .center
        addSubview(label)

        // L'ombre est portée ici plutôt que par la fenêtre : l'ombre système serait calculée sur
        // le cadre complet et resterait donc visible au bord de l'écran pendant que le contenu
        // est encore hors champ, au tout début du glissement.
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.28
        layer?.shadowRadius = 12
        layer?.shadowOffset = CGSize(width: -2, height: 0)

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
        label.textColor = palette.buttonSymbolColor
    }

    override func layout() {
        super.layout()

        let shape = panelPath(in: bounds)
        backgroundLayer.frame = bounds
        backgroundLayer.path = shape
        strokeLayer.frame = bounds
        // Exactement le même chemin que le fond, tracé centré sur la frontière : un `insetBy`
        // uniforme ferait *grandir* le rayon concave là où il rétrécit les rayons convexes, ce qui
        // décollerait la bordure du fond précisément au niveau des raccords.
        strokeLayer.path = shape
        layer?.shadowPath = shape

        let size = label.intrinsicContentSize
        label.frame = NSRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    /// Silhouette complète en un seul chemin fermé : deux coins convexes du côté intérieur, et
    /// deux raccords **concaves** là où le panneau rejoint le bord de l'écran, qui l'évasent comme
    /// un onglet de navigateur s'évase dans sa barre. Les arcs concaves sont décrits avec
    /// `addArc(center:radius:startAngle:endAngle:clockwise:)` et non avec la variante
    /// `tangent1End:tangent2End:`, qui ne sait produire que des coins convexes.
    ///
    /// Tout est dans le même `CGPath` : aucune couture entre le corps et les raccords, et tout ce
    /// qui est hors du chemin reste non peint, donc réellement transparent.
    private func panelPath(in rect: CGRect) -> CGPath {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        let right = rect.maxX      // bord de l'écran
        let left = rect.minX
        let top = rect.maxY
        let bottom = rect.minY

        let path = CGMutablePath()

        // Haut : évasement concave depuis le bord, tangent vertical au contact de celui-ci.
        path.move(to: CGPoint(x: right, y: top))
        path.addArc(
            center: CGPoint(x: right - r, y: top),
            radius: r,
            startAngle: 0,
            endAngle: -.pi / 2,
            clockwise: true
        )

        // Coin convexe haut-intérieur.
        path.addLine(to: CGPoint(x: left + r, y: top - r))
        path.addArc(
            center: CGPoint(x: left + r, y: top - 2 * r),
            radius: r,
            startAngle: .pi / 2,
            endAngle: .pi,
            clockwise: false
        )

        // Côté intérieur droit, puis coin convexe bas-intérieur.
        path.addLine(to: CGPoint(x: left, y: bottom + 2 * r))
        path.addArc(
            center: CGPoint(x: left + r, y: bottom + 2 * r),
            radius: r,
            startAngle: .pi,
            endAngle: 3 * .pi / 2,
            clockwise: false
        )

        // Bas : évasement concave symétrique.
        path.addLine(to: CGPoint(x: right - r, y: bottom + r))
        path.addArc(
            center: CGPoint(x: right - r, y: bottom),
            radius: r,
            startAngle: .pi / 2,
            endAngle: 0,
            clockwise: true
        )

        // Remontée le long du bord de l'écran : le panneau y reste en contact sur toute sa hauteur.
        path.closeSubpath()
        return path
    }

    // MARK: - Animation

    /// Place le contenu hors écran, à droite, et complètement transparent — à appeler avant
    /// d'afficher la fenêtre pour que la première image montrée soit déjà le début du glissement
    /// et non le panneau en place.
    func prepareForReveal(offset: CGFloat) {
        guard let layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.setValue(offset, forKeyPath: "transform.translation.x")
        layer.opacity = 0
        CATransaction.commit()
    }

    func animateIn() {
        guard let layer else { return }
        layer.springAnimate(keyPath: "transform.translation.x", to: CGFloat(0), preset: .gentle)
        animateOpacity(to: 1)
    }

    func animateOut(offset: CGFloat, completion: @escaping () -> Void) {
        guard let layer else {
            completion()
            return
        }
        layer.springAnimate(keyPath: "transform.translation.x", to: offset, preset: .gentle, completion: completion)
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

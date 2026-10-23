import AppKit

/// Contenu du panneau latéral : une carte quasi opaque accrochée au bord droit de l'écran,
/// arrondie du côté intérieur et évasée dans le bord, portant la carte d'utilisation Claude
/// (`ClaudeUsagePanelView`). Porte aussi l'animation d'entrée/sortie (glissement depuis le bord
/// droit + fondu), appliquée à son propre calque.
///
/// Mise en page entièrement en frames, comme le reste de l'overlay (`DockExtensionContentView`,
/// `BrightnessBarView`) — pas de contraintes Auto Layout.
final class SidePanelContentView: NSView {

    /// Les deux silhouettes que porte cette vue. `screenEdge` est la carte accrochée au bord
    /// droit de l'écran (survol du coin supérieur droit) ; `callout` est la bulle posée au-dessus
    /// de la bague du Dock, dont la pointe vise celle-ci.
    enum Shape: Equatable {
        case screenEdge
        /// Abscisse de la pointe dans le repère de la vue — voir `SidePanelGeometry.tailCenterX`.
        case callout(tailCenterX: CGFloat)

        var isCallout: Bool {
            if case .callout = self { return true }
            return false
        }
    }

    var shape: Shape = .screenEdge {
        didSet {
            guard shape != oldValue else { return }
            needsLayout = true
        }
    }

    private let backgroundLayer = CAShapeLayer()
    private let strokeLayer = CAShapeLayer()
    private let usageView = ClaudeUsagePanelView()

    /// Rayon unique de toute la silhouette : il vaut à la fois pour les deux coins convexes
    /// (côté intérieur) et pour les deux raccords concaves qui évasent le panneau dans le bord de
    /// l'écran. À `largeur / 2`, les deux arcs se rejoignent tangentiellement sans segment droit
    /// entre eux — c'est la proportion de la référence.
    private let cornerRadius: CGFloat = 28

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

        addSubview(usageView)

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
    }

    /// Relayé par `SidePanelWindow` depuis le modèle de vue partagé avec la bague du Dock : les
    /// deux surfaces montrent toujours le même instantané.
    func apply(usageState: ClaudeUsageState, animated: Bool) {
        usageView.apply(usageState, animated: animated)
    }

    override func layout() {
        super.layout()

        let path = currentPath(in: bounds)
        backgroundLayer.frame = bounds
        backgroundLayer.path = path
        strokeLayer.frame = bounds
        // Exactement le même chemin que le fond, tracé centré sur la frontière : un `insetBy`
        // uniforme ferait *grandir* le rayon concave là où il rétrécit les rayons convexes, ce qui
        // décollerait la bordure du fond précisément au niveau des raccords.
        strokeLayer.path = path
        layer?.shadowPath = path

        // Le contenu tient dans le corps : la pointe est une excroissance, rien ne s'y dessine.
        usageView.frame = bodyRect(in: bounds)
        // Le bord droit de la bulle est un bord comme un autre, alors que celui de la carte de
        // bord touche l'écran et se fait rogner par les raccords concaves.
        usageView.trailingInset = shape.isCallout ? usageView.leadingInset : SidePanelContentView.edgeTrailingInset
    }

    /// Marge droite de la carte accrochée au bord de l'écran — plus large que la gauche, voir
    /// `ClaudeUsagePanelView`.
    private static let edgeTrailingInset: CGFloat = 26

    private func bodyRect(in rect: CGRect) -> CGRect {
        guard shape.isCallout else { return rect }
        return CGRect(
            x: rect.minX,
            y: rect.minY + SidePanelGeometry.tailLength,
            width: rect.width,
            height: rect.height - SidePanelGeometry.tailLength
        )
    }

    private func currentPath(in rect: CGRect) -> CGPath {
        switch shape {
        case .screenEdge:
            return panelPath(in: rect)
        case .callout(let tailCenterX):
            return calloutPath(in: rect, tailCenterX: tailCenterX)
        }
    }

    /// Bulle : un rectangle arrondi classique, plus une pointe triangulaire sur le bord bas qui
    /// vise la bague. Les coins sont décrits avec `addArc(tangent1End:tangent2End:)`, qui suffit
    /// ici — contrairement à la carte de bord, cette silhouette n'a aucun raccord concave.
    private func calloutPath(in rect: CGRect, tailCenterX: CGFloat) -> CGPath {
        let body = bodyRect(in: rect)
        let r = min(SidePanelGeometry.calloutCornerRadius, min(body.width, body.height) / 2)
        let halfTail = SidePanelGeometry.tailWidth / 2
        let tipY = body.minY - SidePanelGeometry.tailLength

        let path = CGMutablePath()
        path.move(to: CGPoint(x: body.minX + r, y: body.maxY))
        path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY), tangent2End: CGPoint(x: body.maxX, y: body.minY), radius: r)
        path.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY), tangent2End: CGPoint(x: body.minX, y: body.minY), radius: r)

        // Bord bas parcouru vers la gauche, interrompu par la pointe.
        path.addLine(to: CGPoint(x: tailCenterX + halfTail, y: body.minY))
        path.addLine(to: CGPoint(x: tailCenterX, y: tipY))
        path.addLine(to: CGPoint(x: tailCenterX - halfTail, y: body.minY))

        path.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY), tangent2End: CGPoint(x: body.minX, y: body.maxY), radius: r)
        path.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY), tangent2End: CGPoint(x: body.maxX, y: body.maxY), radius: r)
        path.closeSubpath()
        return path
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

    /// Axe et amplitude du glissement, dictés par la silhouette : la carte de bord vient de
    /// derrière le bord droit de l'écran, la bulle monte de quelques points depuis la bague.
    private var revealKeyPath: String {
        shape.isCallout ? "transform.translation.y" : "transform.translation.x"
    }

    private var revealOffset: CGFloat {
        shape.isCallout ? -12 : bounds.width
    }

    /// Place le contenu à son point de départ, complètement transparent — à appeler avant
    /// d'afficher la fenêtre pour que la première image montrée soit déjà le début du glissement
    /// et non le panneau en place.
    func prepareForReveal() {
        guard let layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Les deux axes sont réinitialisés : une même fenêtre passe de la carte de bord à la
        // bulle, et le décalage de la silhouette précédente resterait sinon appliqué.
        layer.setValue(CGFloat(0), forKeyPath: "transform.translation.x")
        layer.setValue(CGFloat(0), forKeyPath: "transform.translation.y")
        layer.setValue(revealOffset, forKeyPath: revealKeyPath)
        layer.opacity = 0
        CATransaction.commit()
    }

    func animateIn() {
        guard let layer else { return }
        layer.springAnimate(keyPath: revealKeyPath, to: CGFloat(0), preset: .gentle)
        animateOpacity(to: 1)
    }

    func animateOut(completion: @escaping () -> Void) {
        guard let layer else {
            completion()
            return
        }
        layer.springAnimate(keyPath: revealKeyPath, to: revealOffset, preset: .gentle, completion: completion)
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

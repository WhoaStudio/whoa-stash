import AppKit

/// Contenu de la bulle d'utilisation : un rectangle arrondi quasi opaque, percé d'une pointe sur
/// l'un de ses bords latéraux qui vise la bague survolée, portant la carte détaillée
/// (`ClaudeUsagePanelView`).
///
/// Même grammaire que `SidePanelContentView` — mise en page en frames, ombre portée par le
/// calque, glissement au ressort — mais une silhouette à elle, puisqu'elle n'est plus accrochée
/// au bord de l'écran.
final class UsageCalloutContentView: NSView {

    /// Bord et hauteur de la pointe, décidés par `SidePanelGeometry` en même temps que le cadre
    /// de la fenêtre.
    var tail: SidePanelGeometry.Tail = .init(edge: .right, centerY: 0) {
        didSet {
            guard tail != oldValue else { return }
            needsLayout = true
        }
    }

    private let backgroundLayer = CAShapeLayer()
    private let strokeLayer = CAShapeLayer()
    private let usageView = ClaudeUsagePanelView()

    private let fadeDuration: TimeInterval = 0.18

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
        layer?.addSublayer(backgroundLayer)

        strokeLayer.fillColor = nil
        strokeLayer.lineWidth = 1
        layer?.addSublayer(strokeLayer)

        // Les deux bords de la bulle sont symétriques, contrairement à ceux de la bande accrochée
        // à l'écran : la carte peut garder la même marge de chaque côté.
        usageView.trailingInset = usageView.leadingInset
        addSubview(usageView)

        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.3
        layer?.shadowRadius = 14
        layer?.shadowOffset = CGSize(width: 0, height: -2)

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

    func apply(usageState: ClaudeUsageState, animated: Bool) {
        usageView.apply(usageState, animated: animated)
    }

    override func layout() {
        super.layout()

        let path = calloutPath(in: bounds)
        backgroundLayer.frame = bounds
        backgroundLayer.path = path
        strokeLayer.frame = bounds
        strokeLayer.path = path
        layer?.shadowPath = path

        // Le contenu tient dans le corps : la pointe est une excroissance, rien ne s'y dessine.
        usageView.frame = bodyRect(in: bounds)
    }

    /// Corps de la bulle : le cadre moins la bande latérale réservée à la pointe.
    private func bodyRect(in rect: CGRect) -> CGRect {
        let tailLength = SidePanelGeometry.tailLength
        return CGRect(
            x: tail.edge == .left ? rect.minX + tailLength : rect.minX,
            y: rect.minY,
            width: rect.width - tailLength,
            height: rect.height
        )
    }

    /// Un rectangle arrondi, plus une pointe triangulaire sur le bord latéral qui vise la bague.
    /// Les coins sont décrits avec `addArc(tangent1End:tangent2End:)`, qui suffit ici : cette
    /// silhouette n'a aucun raccord concave.
    private func calloutPath(in rect: CGRect) -> CGPath {
        let body = bodyRect(in: rect)
        let r = min(SidePanelGeometry.calloutCornerRadius, min(body.width, body.height) / 2)
        let halfTail = SidePanelGeometry.tailWidth / 2
        let centerY = tail.centerY
        let tipX = tail.edge == .right
            ? body.maxX + SidePanelGeometry.tailLength
            : body.minX - SidePanelGeometry.tailLength

        let topLeft = CGPoint(x: body.minX, y: body.maxY)
        let topRight = CGPoint(x: body.maxX, y: body.maxY)
        let bottomRight = CGPoint(x: body.maxX, y: body.minY)
        let bottomLeft = CGPoint(x: body.minX, y: body.minY)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: body.minX + r, y: body.maxY))

        if tail.edge == .right {
            path.addArc(tangent1End: topRight, tangent2End: bottomRight, radius: r)
            // Bord droit parcouru vers le bas, interrompu par la pointe.
            path.addLine(to: CGPoint(x: body.maxX, y: centerY + halfTail))
            path.addLine(to: CGPoint(x: tipX, y: centerY))
            path.addLine(to: CGPoint(x: body.maxX, y: centerY - halfTail))
            path.addArc(tangent1End: bottomRight, tangent2End: bottomLeft, radius: r)
            path.addArc(tangent1End: bottomLeft, tangent2End: topLeft, radius: r)
        } else {
            path.addArc(tangent1End: topRight, tangent2End: bottomRight, radius: r)
            path.addArc(tangent1End: bottomRight, tangent2End: bottomLeft, radius: r)
            path.addArc(tangent1End: bottomLeft, tangent2End: topLeft, radius: r)
            // Bord gauche parcouru vers le haut, interrompu par la pointe.
            path.addLine(to: CGPoint(x: body.minX, y: centerY - halfTail))
            path.addLine(to: CGPoint(x: tipX, y: centerY))
            path.addLine(to: CGPoint(x: body.minX, y: centerY + halfTail))
        }

        path.addArc(tangent1End: topLeft, tangent2End: topRight, radius: r)
        path.closeSubpath()
        return path
    }

    // MARK: - Animation

    /// La bulle vient de la bague : elle glisse de quelques points depuis le côté de sa pointe.
    private var revealOffset: CGFloat { tail.edge == .right ? 12 : -12 }

    func prepareForReveal() {
        guard let layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
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

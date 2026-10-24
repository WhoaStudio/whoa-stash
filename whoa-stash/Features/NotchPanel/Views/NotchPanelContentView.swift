import AppKit

/// Contenu du panneau de l'encoche : une silhouette sombre suspendue au haut de l'écran, qui
/// passe de la forme de l'encoche (ou d'une pastille, sur un Mac sans encoche) à un panneau
/// large portant deux colonnes — les bagues d'utilisation **en ligne** à gauche, la carte
/// détaillée à droite.
///
/// Les deux silhouettes sont décrites par la même recette de chemin, dans le même ordre de
/// segments : Core Animation peut donc interpoler l'une vers l'autre, et c'est ce qui constitue
/// le dépliage. Rien d'autre ne bouge — ni la fenêtre, ni le cadre de la vue.
///
/// Mise en page entièrement en frames, comme le reste de l'overlay.
final class NotchPanelContentView: NSView {

    private let backgroundLayer = CAShapeLayer()
    private let strokeLayer = CAShapeLayer()
    private let contentMask = CAShapeLayer()

    /// Les colonnes vivent dans un conteneur à part pour n'avoir qu'un masque et qu'une opacité
    /// à piloter pendant le dépliage.
    private let contentContainer = NSView()
    private let highlightLayer = CALayer()
    private let dividerLayer = CALayer()
    private let rings: [ClaudeUsageRingView]
    private let card = ClaudeUsagePanelView()

    /// Taille de la silhouette repliée, décidée par l'écran : l'encoche matérielle n'a pas les
    /// mêmes dimensions d'un Mac à l'autre, et une pastille les remplace quand il n'y en a pas.
    var collapsedSize: NSSize = NotchPanelGeometry.pillSize {
        didSet {
            guard collapsedSize != oldValue else { return }
            needsLayout = true
        }
    }

    private(set) var isExpanded = false

    /// Durée du fondu du contenu. Le dépliage de la silhouette, lui, est porté par un ressort.
    private let fadeDuration: TimeInterval = 0.18

    override init(frame frameRect: NSRect) {
        rings = SidePanelGeometry.ringSlots.map { slot in
            ClaudeUsageRingView(tileSize: NotchPanelGeometry.ringTileSize, mark: slot.mark)
        }
        super.init(frame: frameRect)
        wantsLayer = true
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        // Fond plein et non `NSVisualEffectView` : sur un Mac à encoche la silhouette repliée
        // doit se confondre avec du noir matériel, qu'aucun matériau translucide n'imite.
        layer?.addSublayer(backgroundLayer)

        strokeLayer.fillColor = nil
        strokeLayer.lineWidth = 1
        layer?.addSublayer(strokeLayer)

        contentContainer.wantsLayer = true
        // Le contenu est découpé par la silhouette elle-même : pendant le dépliage il ne doit
        // rien dépasser de la forme, qui est encore plus étroite que lui.
        contentContainer.layer?.mask = contentMask
        contentContainer.layer?.opacity = 0
        addSubview(contentContainer)

        // Plaque d'accent derrière la bague survolée — l'équivalent ici de l'onglet actif de la
        // référence, le seul endroit où le panneau a quelque chose d'« actif » à désigner.
        highlightLayer.backgroundColor = OverlayPalette.activeGreen.copy(alpha: 0.14)
        highlightLayer.shadowColor = OverlayPalette.activeGreen
        highlightLayer.shadowOpacity = 0.35
        highlightLayer.shadowRadius = 10
        highlightLayer.shadowOffset = .zero
        highlightLayer.opacity = 0
        contentContainer.layer?.addSublayer(highlightLayer)

        rings.forEach(contentContainer.addSubview)
        // Les cases sans source partent — et restent — sur un anneau vide, comme dans la bande
        // du bord droit.
        for (position, ring) in rings.enumerated() where !SidePanelGeometry.ringSlots[position].isConnected {
            ring.apply(.unavailable(reason: "Not connected"), animated: false)
        }

        contentContainer.layer?.addSublayer(dividerLayer)

        // Les deux bords de la colonne de droite sont symétriques : rien ne la pousse contre un
        // bord d'écran, contrairement à la carte de la bande latérale.
        card.trailingInset = card.leadingInset
        contentContainer.addSubview(card)

        // L'ombre est portée par le calque et non par la fenêtre : l'ombre système serait
        // calculée sur le cadre complet et cernerait l'encoche alors que le panneau est replié.
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0
        layer?.shadowRadius = 18
        layer?.shadowOffset = CGSize(width: 0, height: -6)

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
        dividerLayer.backgroundColor = palette.strokeColor
    }

    // MARK: - État

    func apply(usageState: ClaudeUsageState, animated: Bool) {
        for (position, ring) in rings.enumerated() where SidePanelGeometry.ringSlots[position].isConnected {
            ring.apply(usageState, animated: animated)
        }
        card.apply(usageState, animated: animated)
    }

    var ringCount: Int { rings.count }

    /// Cadre d'une bague dans le repère de cette vue : `NotchPanelWindow` le convertit en
    /// coordonnées écran pour que le contrôleur puisse y confronter le curseur.
    func ringFrame(at index: Int) -> NSRect? {
        guard rings.indices.contains(index) else { return nil }
        return contentContainer.convert(rings[index].frame, to: self)
    }

    /// Met en avant la bague survolée et déplace la plaque d'accent sous elle. Le panneau ne
    /// reçoit aucun événement de souris : c'est le contrôleur qui désigne la bague.
    func setHighlightedRing(_ index: Int?) {
        for (position, ring) in rings.enumerated() {
            ring.setHighlighted(position == index)
        }

        guard let index, rings.indices.contains(index) else {
            highlightLayer.springAnimate(keyPath: "opacity", to: Float(0), preset: .snappy)
            return
        }

        let target = rings[index].frame.insetBy(dx: -8, dy: -6)
        CATransaction.begin()
        CATransaction.setDisableActions(highlightLayer.opacity == 0)
        highlightLayer.frame = target
        highlightLayer.cornerRadius = 14
        CATransaction.commit()
        highlightLayer.springAnimate(keyPath: "opacity", to: Float(1), preset: .snappy)
    }

    // MARK: - Mise en page

    override func layout() {
        super.layout()

        applyShape(expanded: isExpanded, animated: false)

        let inset = NotchPanelGeometry.contentInsetX
        let tile = NotchPanelGeometry.ringTileSize
        let rowWidth = NotchPanelGeometry.ringRowWidth

        contentContainer.frame = bounds

        // Colonne de gauche : les bagues en ligne, centrées sur la hauteur utile.
        let usableTop = bounds.maxY - NotchPanelGeometry.contentInsetTop
        let usableBottom = bounds.minY + NotchPanelGeometry.contentInsetBottom
        let ringY = (usableTop + usableBottom) / 2 - tile / 2

        for (position, ring) in rings.enumerated() {
            ring.frame = NSRect(
                x: inset + CGFloat(position) * (tile + NotchPanelGeometry.ringSpacing),
                y: ringY,
                width: tile,
                height: tile
            )
        }

        let dividerX = inset + rowWidth + NotchPanelGeometry.columnGap
        dividerLayer.frame = NSRect(
            x: dividerX,
            y: usableBottom + 8,
            width: NotchPanelGeometry.dividerWidth,
            height: max(0, usableTop - usableBottom - 16)
        )

        // Colonne de droite : la carte détaillée, à la hauteur que sa mise en page demande.
        card.frame = NSRect(
            x: dividerX + NotchPanelGeometry.dividerWidth + NotchPanelGeometry.columnGap,
            y: (usableTop + usableBottom) / 2 - NotchPanelGeometry.cardSize.height / 2,
            width: NotchPanelGeometry.cardSize.width,
            height: NotchPanelGeometry.cardSize.height
        )
    }

    // MARK: - Silhouette

    /// Silhouette en un seul chemin fermé, suspendue au bord **haut** de la vue : deux raccords
    /// concaves en haut, qui évasent le panneau dans ce bord comme un onglet s'évase dans sa
    /// barre, et deux coins convexes en bas.
    ///
    /// La recette est la même pour les deux états, au nombre et à l'ordre des segments près :
    /// c'est cette identité de structure qui rend les deux chemins interpolables, et donc le
    /// dépliage animable d'un seul `CASpringAnimation` sur `path`.
    private func panelPath(width: CGFloat, height: CGFloat, shoulder: CGFloat, bottom: CGFloat) -> CGPath {
        let w = min(width, bounds.width)
        let h = min(height, bounds.height)
        // Les quatre rayons doivent tenir dans la silhouette, qui est minuscule une fois repliée.
        let r = min(shoulder, w / 4, h / 2)
        let b = min(bottom, w / 2 - r, h - r)

        let left = bounds.midX - w / 2
        let right = bounds.midX + w / 2
        let top = bounds.maxY
        let bottomY = top - h

        let path = CGMutablePath()

        // Haut-gauche : évasement concave depuis le bord auquel le panneau est suspendu.
        path.move(to: CGPoint(x: left, y: top))
        path.addArc(
            center: CGPoint(x: left + r, y: top),
            radius: r,
            startAngle: .pi,
            endAngle: 3 * .pi / 2,
            clockwise: false
        )

        // Côté gauche, puis coin convexe bas-gauche.
        path.addLine(to: CGPoint(x: left + r, y: bottomY + b))
        path.addArc(
            center: CGPoint(x: left + r + b, y: bottomY + b),
            radius: b,
            startAngle: .pi,
            endAngle: 3 * .pi / 2,
            clockwise: false
        )

        // Bas, puis coin convexe bas-droit.
        path.addLine(to: CGPoint(x: right - r - b, y: bottomY))
        path.addArc(
            center: CGPoint(x: right - r - b, y: bottomY + b),
            radius: b,
            startAngle: -.pi / 2,
            endAngle: 0,
            clockwise: false
        )

        // Côté droit, puis évasement concave haut-droit.
        path.addLine(to: CGPoint(x: right - r, y: top - r))
        path.addArc(
            center: CGPoint(x: right - r, y: top),
            radius: r,
            startAngle: 3 * .pi / 2,
            endAngle: 2 * .pi,
            clockwise: false
        )

        // Le bord du haut referme la silhouette : c'est par lui qu'elle tient à l'écran.
        path.closeSubpath()
        return path
    }

    private func collapsedPath() -> CGPath {
        panelPath(
            width: collapsedSize.width,
            height: collapsedSize.height,
            shoulder: NotchPanelGeometry.collapsedShoulderRadius,
            bottom: NotchPanelGeometry.collapsedBottomRadius
        )
    }

    private func expandedPath() -> CGPath {
        panelPath(
            width: bounds.width,
            height: bounds.height,
            shoulder: NotchPanelGeometry.expandedShoulderRadius,
            bottom: NotchPanelGeometry.expandedBottomRadius
        )
    }

    // MARK: - Dépliage

    /// Replie ou déplie le panneau. Seule la silhouette s'anime : la fenêtre garde en
    /// permanence le cadre déplié (voir `NotchPanelGeometry.windowFrame`).
    func setExpanded(_ expanded: Bool, animated: Bool) {
        guard expanded != isExpanded else { return }
        isExpanded = expanded
        applyShape(expanded: expanded, animated: animated)
    }

    private func applyShape(expanded: Bool, animated: Bool) {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let path = expanded ? expandedPath() : collapsedPath()
        let shadowOpacity: Float = expanded ? 0.45 : 0
        let contentOpacity: Float = expanded ? 1 : 0

        guard animated else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for shape in [backgroundLayer, strokeLayer, contentMask] {
                shape.frame = bounds
                shape.path = path
            }
            layer?.shadowPath = path
            layer?.shadowOpacity = shadowOpacity
            contentContainer.layer?.opacity = contentOpacity
            CATransaction.commit()
            return
        }

        for shape in [backgroundLayer, strokeLayer, contentMask] {
            shape.frame = bounds
            shape.springAnimate(keyPath: "path", to: path, preset: .gentle)
        }

        layer?.shadowPath = path
        animate(layer, keyPath: "shadowOpacity", to: shadowOpacity)
        // Le contenu suit le dépliage en fondu plutôt qu'en ressort : il doit avoir disparu
        // avant que la silhouette ne soit redevenue trop étroite pour le contenir.
        animate(contentContainer.layer, keyPath: "opacity", to: contentOpacity)
    }

    private func animate(_ target: CALayer?, keyPath: String, to value: Float) {
        guard let target else { return }

        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = target.presentation()?.value(forKeyPath: keyPath) ?? target.value(forKeyPath: keyPath)
        animation.toValue = value
        animation.duration = fadeDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        target.setValue(value, forKeyPath: keyPath)
        target.add(animation, forKey: keyPath)
    }
}

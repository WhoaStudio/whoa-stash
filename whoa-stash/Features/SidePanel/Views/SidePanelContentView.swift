import AppKit

/// Contenu du panneau latéral : une surface quasi opaque accrochée au bord droit de l'écran,
/// arrondie du côté intérieur et évasée dans le bord.
///
/// Porte une barre d'onglets en haut (`NotchTabBarView`) et, dessous, l'onglet choisi : Global
/// (la semaine et les bagues d'utilisation), Tray (le bac à fichiers) ou AI. La carte détaillée
/// d'une bague, elle, vit dans la bulle qui s'ouvre à son survol (`UsageCalloutWindow`).
///
/// Porte aussi l'animation d'entrée/sortie (glissement depuis le bord droit + fondu), appliquée
/// à son propre calque.
///
/// Mise en page entièrement en frames, comme le reste de l'overlay (`BrightnessBarView`) —
/// pas de contraintes Auto Layout.
final class SidePanelContentView: NSView {

    /// Appelé au clic sur l'engrenage de la barre d'onglets. Relayé jusqu'à `SidePanelController`,
    /// qui seul sait ouvrir les Préférences — la vue n'a pas à connaître la fenêtre de réglages.
    var onOpenSettings: (() -> Void)?

    private let backgroundLayer = CAShapeLayer()
    private let strokeLayer = CAShapeLayer()

    private let tabBar = NotchTabBarView(selectedTab: .global)
    private let globalTab = NotchGlobalTabView()
    private let fileTray = FileTrayView()
    private let aiTab = AIPlaceholderView()

    private var selectedTab: NotchTab = .global

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
        strokeLayer.lineWidth = 1
        layer?.addSublayer(strokeLayer)

        tabBar.onSelect = { [weak self] tab in self?.select(tab, animated: true) }
        tabBar.onOpenSettings = { [weak self] in self?.onOpenSettings?() }
        addSubview(tabBar)

        for view in tabContentViews {
            addSubview(view)
        }
        applySelection(animated: false)

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

    /// Relayé par `SidePanelWindow` depuis le modèle de vue partagé avec la bulle : les deux
    /// surfaces montrent toujours le même instantané.
    func apply(usageState: ClaudeUsageState, animated: Bool) {
        globalTab.apply(usageState: usageState, animated: animated)
    }

    /// Met en avant la bague survolée — le contrôleur la désigne depuis la position du curseur.
    func setHighlightedRing(_ index: Int?) {
        globalTab.setHighlightedRing(index)
    }

    /// Cadre d'une bague dans le repère de cette vue : `SidePanelWindow` le convertit en
    /// coordonnées écran pour que la bulle sache où pointer.
    ///
    /// `nil` hors de l'onglet Global : les bagues y sont alors masquées, et le contrôleur ne doit
    /// pas ouvrir une bulle qui pointerait vers le bac à fichiers.
    func ringFrame(at index: Int) -> NSRect? {
        guard selectedTab == .global, let frame = globalTab.ringFrame(at: index) else { return nil }
        return globalTab.convert(frame, to: self)
    }

    var ringCount: Int { globalTab.ringCount }

    // MARK: - Onglets

    private var tabContentViews: [NSView] { [globalTab, fileTray, aiTab] }

    private func contentView(for tab: NotchTab) -> NSView {
        switch tab {
        case .global: globalTab
        case .tray: fileTray
        case .ai: aiTab
        }
    }

    /// Bascule d'onglet. Appelée par la barre au clic, et par le contrôleur quand il remet le
    /// panneau sur Global avant une nouvelle apparition.
    func select(_ tab: NotchTab, animated: Bool) {
        guard tab != selectedTab else { return }
        selectedTab = tab
        tabBar.select(tab, animated: animated)
        applySelection(animated: animated)
    }

    /// Montre l'onglet choisi et retire les autres. Les vues inactives sont réellement masquées,
    /// et pas seulement transparentes : le bac à fichiers ne doit pas capter un glisser pendant
    /// qu'un autre onglet est affiché.
    private func applySelection(animated: Bool) {
        let active = contentView(for: selectedTab)

        for view in tabContentViews {
            let isActive = view === active
            view.isHidden = !isActive
            guard animated, isActive else {
                view.layer?.opacity = isActive ? 1 : 0
                continue
            }
            // Fondu d'entrée seul : l'onglet qui s'en va est retiré d'un coup, donc les deux ne se
            // superposent jamais pendant la transition.
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = fadeDuration
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view.layer?.opacity = 1
            view.layer?.add(fade, forKey: "opacity")
        }
    }

    /// Remet le panneau dans son état d'ouverture : l'onglet Global, et sa semaine à la bonne
    /// date. Appelé juste avant chaque apparition — le panneau reste en mémoire d'un survol à
    /// l'autre, et parfois d'un jour à l'autre.
    func prepareForDisplay() {
        select(.global, animated: false)
        globalTab.refreshWeek()
    }

    override func layout() {
        super.layout()

        let path = panelPath(in: bounds)
        backgroundLayer.frame = bounds
        backgroundLayer.path = path
        strokeLayer.frame = bounds
        // Exactement le même chemin que le fond, tracé centré sur la frontière : un `insetBy`
        // uniforme ferait *grandir* le rayon concave là où il rétrécit les rayons convexes, ce qui
        // décollerait la bordure du fond précisément au niveau des raccords.
        strokeLayer.path = path
        layer?.shadowPath = path

        // Boîte de contenu : tout ce qui est peint reste sous la ligne où le bord supérieur se
        // relève vers le bord de l'écran pour former l'évasement (voir `panelPath`).
        let box = bounds.insetBy(
            dx: SidePanelGeometry.contentHorizontalInset,
            dy: SidePanelGeometry.contentVerticalInset
        )

        let tabHeight = SidePanelGeometry.tabBarHeight
        tabBar.frame = NSRect(
            x: box.minX,
            y: box.maxY - tabHeight,
            width: box.width,
            height: tabHeight
        )

        let bodyHeight = max(0, tabBar.frame.minY - SidePanelGeometry.contentSpacing - box.minY)
        let body = NSRect(x: box.minX, y: box.minY, width: box.width, height: bodyHeight)
        for view in tabContentViews {
            view.frame = body
        }
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

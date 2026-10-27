import AppKit

/// Contenu du panneau de l'encoche : une silhouette sombre suspendue au haut de l'écran, qui
/// passe de la forme de l'encoche (ou d'une pastille, sur un Mac sans encoche) à un panneau
/// large portant une barre d'onglets et, dessous, l'onglet choisi. Global porte la semaine ; AI
/// porte les deux colonnes d'utilisation — les bagues **en ligne** à gauche, la carte détaillée
/// à droite ; Tray reprend le bac à fichiers partagé avec la bande du bord droit.
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

    /// Appelé au clic sur l'engrenage de la barre d'onglets, relayé jusqu'au contrôleur.
    var onOpenSettings: (() -> Void)?

    private let tabBar = NotchTabBarView(selectedTab: .global)

    /// L'onglet Global : la semaine, seule.
    private let globalTab = NSView()
    private let weekStrip = WeekStripView()
    private let fileTray = FileTrayView()

    /// L'onglet AI : les deux colonnes d'utilisation — les bagues et la carte —, qui se montrent
    /// et se cachent d'un bloc avec lui.
    private let aiColumns = NSView()

    private var selectedTab: NotchTab = .global

    /// Taille de la silhouette repliée, décidée par l'écran : l'encoche matérielle n'a pas les
    /// mêmes dimensions d'un Mac à l'autre, et une pastille les remplace quand il n'y en a pas.
    var collapsedSize: NSSize = NotchPanelGeometry.pillSize {
        didSet {
            guard collapsedSize != oldValue else { return }
            needsLayout = true
        }
    }

    private(set) var isExpanded = false

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
        // Clic droit : le menu partagé par tous les panneaux de l'overlay. Posé ici plutôt que
        // sur chaque enfant — AppKit remonte la chaîne des responders jusqu'à la première vue
        // qui porte un menu.
        menu = OverlayContextMenu.shared.menu

        // Fond plein et non `NSVisualEffectView` : sur un Mac à encoche la silhouette repliée
        // doit se confondre avec du noir matériel, qu'aucun matériau translucide n'imite.
        layer?.addSublayer(backgroundLayer)

        strokeLayer.fillColor = nil
        strokeLayer.lineWidth = PanelGeometry.strokeWidth
        layer?.addSublayer(strokeLayer)

        contentContainer.wantsLayer = true
        // Le contenu est découpé par la silhouette elle-même : pendant le dépliage il ne doit
        // rien dépasser de la forme, qui est encore plus étroite que lui.
        contentContainer.layer?.mask = contentMask
        contentContainer.layer?.opacity = 0
        addSubview(contentContainer)

        // Plaque d'accent derrière la bague survolée — l'équivalent ici de l'onglet actif de la
        // référence, le seul endroit où le panneau a quelque chose d'« actif » à désigner.
        // Teinte et ombre sont posées par `applyPalette()`, appelé en fin d'installation.
        highlightLayer.shadowOpacity = 0.35
        highlightLayer.shadowRadius = 10
        highlightLayer.shadowOffset = .zero
        highlightLayer.opacity = 0
        aiColumns.wantsLayer = true
        aiColumns.layer?.addSublayer(highlightLayer)
        contentContainer.addSubview(aiColumns)

        rings.forEach(aiColumns.addSubview)
        // Les cases sans source partent — et restent — sur un anneau vide, comme dans la bande
        // du bord droit.
        for (position, ring) in rings.enumerated() where !SidePanelGeometry.ringSlots[position].isConnected {
            ring.apply(.unavailable(reason: "Not connected"), animated: false)
        }

        aiColumns.layer?.addSublayer(dividerLayer)

        // Les deux bords de la colonne de droite sont symétriques : rien ne la pousse contre un
        // bord d'écran, contrairement à la carte de la bande latérale.
        card.trailingInset = card.leadingInset
        aiColumns.addSubview(card)

        globalTab.addSubview(weekStrip)
        contentContainer.addSubview(globalTab)

        tabBar.onSelect = { [weak self] tab in self?.select(tab, animated: true) }
        tabBar.onOpenSettings = { [weak self] in self?.onOpenSettings?() }
        contentContainer.addSubview(tabBar)

        contentContainer.addSubview(fileTray)
        applySelection(animated: false)

        // Aucune ombre portée : la silhouette se détache par sa teinte et son filet, et la
        // fenêtre est elle aussi sans ombre (`NotchPanelWindow`).
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
        dividerLayer.backgroundColor = palette.strokeColor
        // La plaque de survol suit la couleur d'accent choisie, comme les graduations du widget
        // de luminosité : c'est la même teinte « active » des deux côtés de l'overlay.
        highlightLayer.backgroundColor = palette.activeTickColor.copy(alpha: 0.14)
        highlightLayer.shadowColor = palette.activeTickColor
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
    /// `nil` hors de l'onglet AI : les bagues y sont masquées, et le contrôleur ne doit pas y
    /// confronter le curseur.
    func ringFrame(at index: Int) -> NSRect? {
        guard selectedTab == .ai, rings.indices.contains(index) else { return nil }
        return aiColumns.convert(rings[index].frame, to: self)
    }

    /// Met en avant la bague survolée et déplace la plaque d'accent sous elle. Le panneau ne
    /// reçoit aucun événement de souris : c'est le contrôleur qui désigne la bague.
    func setHighlightedRing(_ index: Int?) {
        let index = selectedTab == .ai ? index : nil
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

    // MARK: - Onglets

    private var tabContentViews: [NSView] { [globalTab, fileTray, aiColumns] }

    private func contentView(for tab: NotchTab) -> NSView {
        switch tab {
        case .global: globalTab
        case .tray: fileTray
        case .ai: aiColumns
        }
    }

    /// Bascule d'onglet, au clic dans la barre ou au repli du panneau, qui ramène sur Global.
    /// Remet la semaine à la bonne date — appelé à chaque dépliage, le panneau restant en
    /// mémoire d'un survol à l'autre et parfois d'un jour à l'autre.
    func refreshWeek() {
        weekStrip.refresh()
    }

    func select(_ tab: NotchTab, animated: Bool) {
        guard tab != selectedTab else { return }
        selectedTab = tab
        tabBar.select(tab, animated: animated)
        // La plaque d'accent suit une bague : elle n'a plus rien à désigner ailleurs.
        setHighlightedRing(nil)
        applySelection(animated: animated)
    }

    /// Montre l'onglet choisi et retire les autres. Les vues inactives sont réellement masquées
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
            // Fondu d'entrée seul : l'onglet qui s'en va est retiré d'un coup, donc les deux ne
            // se superposent jamais.
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = PanelFold.fadeDuration
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
            view.layer?.opacity = 1
            view.layer?.add(fade, forKey: "opacity")
        }
    }

    // MARK: - Mise en page

    override func layout() {
        super.layout()

        applyShape(expanded: isExpanded, animated: false)

        let inset = NotchPanelGeometry.contentInsetX
        let tile = NotchPanelGeometry.ringTileSize
        let rowWidth = NotchPanelGeometry.ringRowWidth

        contentContainer.frame = bounds

        // Barre d'onglets en haut, sous la marge que laissent les raccords concaves.
        let barHeight = TabBarMetrics.barHeight
        tabBar.frame = NSRect(
            x: inset,
            y: bounds.maxY - NotchPanelGeometry.contentInsetTop(forCollapsedHeight: collapsedSize.height) - barHeight,
            width: max(0, bounds.width - 2 * inset),
            height: barHeight
        )

        // Corps de l'onglet : tout ce qui reste sous la barre. Les trois onglets l'occupent en
        // entier et se relaient dedans.
        let bodyTop = tabBar.frame.minY - NotchPanelGeometry.tabBarGap
        let bodyBottom = bounds.minY + NotchPanelGeometry.contentInsetBottom
        let body = NSRect(
            x: bounds.minX,
            y: bodyBottom,
            width: bounds.width,
            height: max(0, bodyTop - bodyBottom)
        )
        for view in tabContentViews {
            // Les colonnes de l'onglet AI posent elles-mêmes leur marge, bague par bague et
            // colonne par colonne ; les autres onglets reçoivent un corps déjà marginé.
            view.frame = view === aiColumns
                ? body
                : body.insetBy(dx: inset, dy: 0)
        }

        // Dans le repère de `globalTab` : la semaine en tête, sur toute la largeur utile. Le
        // corps est plus haut qu'elle — c'est l'onglet AI qui le dimensionne — et elle reste en
        // tête plutôt que centrée, à la place qu'elle occupait quand les colonnes la suivaient.
        let weekHeight = NotchPanelGeometry.weekStripHeight
        weekStrip.frame = NSRect(
            x: globalTab.bounds.minX,
            y: globalTab.bounds.maxY - weekHeight,
            width: globalTab.bounds.width,
            height: weekHeight
        )

        // Dans le repère de `aiColumns` : les deux colonnes se partagent toute sa hauteur.
        let columnsTop = aiColumns.bounds.maxY
        let columnsBottom = aiColumns.bounds.minY
        let columnsMidY = (columnsTop + columnsBottom) / 2

        // Colonne de gauche : les bagues en ligne, centrées sur la hauteur restante.
        let ringY = columnsMidY - tile / 2
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
            y: columnsBottom + 8,
            width: NotchPanelGeometry.dividerWidth,
            height: max(0, columnsTop - columnsBottom - 16)
        )

        // Colonne de droite : la carte détaillée, à la hauteur que sa mise en page demande.
        card.frame = NSRect(
            x: dividerX + NotchPanelGeometry.dividerWidth + NotchPanelGeometry.columnGap,
            y: columnsMidY - NotchPanelGeometry.cardSize.height / 2,
            width: NotchPanelGeometry.cardSize.width,
            height: NotchPanelGeometry.cardSize.height
        )
    }

    // MARK: - Silhouette

    /// Les deux états, tirés de la même recette que les bandes de flanc
    /// (`PanelGeometry.silhouette`), ici suspendue au bord du **haut** : deux raccords concaves
    /// qui évasent le panneau dans ce bord comme un onglet s'évase dans sa barre, et deux coins
    /// convexes en bas. Seuls la taille et les rayons les distinguent, donc les deux chemins ont
    /// le même nombre de segments dans le même ordre — c'est cette identité de structure qui rend
    /// le dépliage animable d'un seul `CASpringAnimation` sur `path`.

    private func collapsedPath() -> CGPath {
        PanelGeometry.silhouette(
            in: bounds,
            anchoredTo: .top,
            size: collapsedSize,
            shoulderRadius: NotchPanelGeometry.collapsedShoulderRadius,
            farRadius: NotchPanelGeometry.collapsedBottomRadius
        )
    }

    private func expandedPath() -> CGPath {
        PanelGeometry.silhouette(
            in: bounds,
            anchoredTo: .top,
            shoulderRadius: NotchPanelGeometry.expandedShoulderRadius,
            farRadius: NotchPanelGeometry.expandedBottomRadius
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

        // Le contenu suit le dépliage en fondu plutôt qu'au ressort, et il est découpé par la
        // silhouette elle-même (`contentMask`) : pendant le dépliage il ne doit rien dépasser de
        // la forme, qui est encore plus étroite que lui.
        PanelFold.apply(
            path: expanded ? expandedPath() : collapsedPath(),
            to: [backgroundLayer, strokeLayer, contentMask],
            in: bounds,
            fading: contentContainer.layer.map { [$0] } ?? [],
            to: expanded ? 1 : 0,
            animated: animated
        )
    }
}

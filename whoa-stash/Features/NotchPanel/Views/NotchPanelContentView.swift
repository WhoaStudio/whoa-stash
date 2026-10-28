import AppKit

/// Contenu du panneau de l'encoche : une silhouette sombre suspendue au haut de l'écran, qui
/// passe de la forme de l'encoche (ou d'une pastille, sur un Mac sans encoche) à un panneau
/// large portant l'onglet choisi, surmonté d'une capsule de navigation détachée, posée sous lui
/// et qui n'est donc pas un morceau de sa silhouette. Global porte la semaine ; Calendar porte
/// l'agenda et la grille mensuelle ; AI
/// porte le bloc d'utilisation (`NotchUsageTabView`), plus haut que les autres : le panneau ne
/// grandit que pour lui ; Tray affiche le bac à fichiers, qui vit hors de la vue (`FileShelfStore`) et
/// retient donc ce qu'on y dépose d'un dépliage à l'autre, et d'un lancement à l'autre.
///
/// Les deux silhouettes sont décrites par la même recette de chemin, dans le même ordre de
/// segments : Core Animation peut donc interpoler l'une vers l'autre, et c'est ce qui constitue
/// le dépliage. Rien d'autre ne bouge — ni la fenêtre, ni le cadre de la vue.
///
/// Mise en page entièrement en frames, comme le reste de l'overlay.
final class NotchPanelContentView: NSView {

    /// Fond plein : c'est lui qui se confond avec le noir de l'encoche tant que le panneau est
    /// replié, puis il s'efface au profit du verre.
    private let backgroundLayer = CAShapeLayer()
    /// Fond en verre du panneau déplié, découpé par la même silhouette que `backgroundLayer`.
    private let glass = GlassBackdrop()
    private let strokeLayer = CAShapeLayer()
    private let contentMask = CAShapeLayer()

    /// Les colonnes vivent dans un conteneur à part pour n'avoir qu'un masque et qu'une opacité
    /// à piloter pendant le dépliage.
    private let contentContainer = NSView()

    /// Appelé au clic sur l'engrenage (capsule ou en-tête de l'onglet AI), relayé jusqu'au
    /// contrôleur.
    var onOpenSettings: (() -> Void)? {
        didSet { usageTab.onOpenSettings = onOpenSettings }
    }

    /// Appelé au clic sur « actualiser » de l'onglet AI.
    var onRefreshUsage: (() -> Void)? {
        didSet { usageTab.onRefresh = onRefreshUsage }
    }

    /// La capsule de navigation, posée sous le panneau et détachée de lui : elle vit donc hors
    /// de `contentContainer`, que la silhouette découpe.
    private let capsule = NotchTabCapsuleView(selectedTab: .global)

    /// État d'un appareil Bluetooth qui vient de se connecter : l'encoche s'élargit de part et
    /// d'autre, sans changer de hauteur, et cette vue porte le glyphe à gauche et la batterie à
    /// droite, dans les deux ailes ainsi ouvertes.
    private let deviceStatusPill = DeviceStatusPillView()
    private var isShowingDeviceStatus = false

    /// L'onglet Global : la semaine horizontale.
    private let globalTab = NSView()
    private let weekStrip = WeekStripView()
    /// L'onglet Calendar : l'agenda et la grille du mois.
    private let calendarTab = NSView()
    private let calendarWidget = CalendarWidgetView()
    private let fileTray = FileTrayView()

    /// L'onglet AI : en-tête, carte du fournisseur, filtres et activité.
    private let usageTab = NotchUsageTabView()

    /// L'onglet Mirror : la caméra n'est allumée que pendant qu'il est à l'écran (voir
    /// `updateCameraActivity()`).
    private let mirrorTab = CameraMirrorView(
        viewModel: CameraMirrorViewModel(
            provider: MockCameraMirrorProvider.fromLaunchArguments() ?? AVCameraMirrorService()))

    private var selectedTab: NotchTab = .global

    /// Place de repos de la capsule, relevée à chaque mise en page : c'est de là qu'elle part
    /// en sortant, et c'est là qu'elle revient en entrant.
    private var capsuleRestingPosition: CGPoint = .zero

    /// Silhouette courante, retenue pour le test de contact : le cadre de la fenêtre vaut
    /// toujours le cadre déplié, donc la vue est bien plus large que ce qu'elle dessine, et
    /// seule la forme peinte doit répondre (voir `hitTest(_:)`).
    private var silhouette: CGPath?

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

        // Replié, fond plein : sur un Mac à encoche la silhouette doit se confondre avec du noir
        // matériel, qu'aucun verre n'imite. Déplié, le verre prend le relais (`applyGlassReveal`).
        layer?.addSublayer(backgroundLayer)
        // Du noir de l'encoche en haut vers le verre en bas : le panneau déplié sort de
        // l'encoche au lieu d'y être collé.
        glass.fadeToGlass(from: CGPoint(x: 0.5, y: 1), to: CGPoint(x: 0.5, y: 0))
        addSubview(glass)

        strokeLayer.fillColor = nil
        strokeLayer.lineWidth = PanelGeometry.strokeWidth
        layer?.addSublayer(strokeLayer)

        contentContainer.wantsLayer = true
        // Le contenu est découpé par la silhouette elle-même : pendant le dépliage il ne doit
        // rien dépasser de la forme, qui est encore plus étroite que lui.
        contentContainer.layer?.mask = contentMask
        contentContainer.layer?.opacity = 0
        addSubview(contentContainer)

        contentContainer.addSubview(usageTab)
        contentContainer.addSubview(mirrorTab)

        globalTab.addSubview(weekStrip)
        contentContainer.addSubview(globalTab)

        calendarTab.addSubview(calendarWidget)
        contentContainer.addSubview(calendarTab)
        contentContainer.addSubview(fileTray)

        // Hors du conteneur de contenu, et donc hors du masque de la silhouette : la capsule est
        // justement ce qui se trouve en dehors d'elle. Elle part invisible et suit le dépliage en
        // fondu, comme le contenu.
        capsule.onSelect = { [weak self] tab in self?.select(tab, animated: true) }
        capsule.onOpenSettings = { [weak self] in self?.onOpenSettings?() }
        capsule.layer?.opacity = 0
        addSubview(capsule)
        deviceStatusPill.layer?.opacity = 0
        addSubview(deviceStatusPill)
        applySelection(animated: false)

        // Le panneau tout entier est la cible de dépôt, et pas le rectangle du bac : un fichier
        // se lâche sur l'encoche — en haut, là où la silhouette repliée se voit —, alors que le
        // bac occupe le bas du panneau déplié. Viser le bac demanderait de traverser tout le
        // panneau avant de relâcher. Le bac reste seul à savoir quoi faire du dépôt.
        registerForDraggedTypes([.fileURL])

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
        glass.applyTint(from: palette)
        strokeLayer.strokeColor = palette.strokeColor
    }

    // MARK: - État

    func apply(usageState: ClaudeUsageState, animated: Bool) {
        usageTab.apply(claude: usageState)
    }

    func apply(copilotUsageState: CopilotUsageState) {
        usageTab.apply(copilot: copilotUsageState)
    }

    /// Ce que le curseur doit encore toucher pour garder le panneau déplié : le panneau de
    /// l'onglet affiché et la capsule, et non le cadre entier de la fenêtre, qui est plus haut
    /// que les onglets courts.
    var interactiveFrame: NSRect {
        // Le cadre visé ne suffit pas pendant le glissement d'un onglet à l'autre : la capsule
        // est encore peinte à son ancienne place, et le curseur posé dessus ne doit pas
        // refermer le panneau.
        NotchPanelGeometry.panelRect(in: bounds, tab: selectedTab)
            .union(NotchPanelGeometry.capsuleRect(in: bounds, tab: selectedTab))
            .union(capsuleOnScreenFrame)
    }

    /// Cadre où la capsule est réellement peinte, glissement compris — celui du modèle n'est
    /// atteint qu'à la fin du ressort.
    private var capsuleOnScreenFrame: CGRect {
        capsule.layer?.presentation()?.frame ?? capsule.frame
    }

    // MARK: - Onglets

    private var tabContentViews: [NSView] { [globalTab, calendarTab, fileTray, mirrorTab, usageTab] }

    private func contentView(for tab: NotchTab) -> NSView {
        switch tab {
        case .global: globalTab
        case .calendar: calendarTab
        case .tray: fileTray
        case .mirror: mirrorTab
        case .ai: usageTab
        }
    }

    func apply(agendaState: CalendarAgendaState) {
        calendarWidget.apply(agendaState)
    }

    /// Remet la semaine et le calendrier à la bonne date — appelé à chaque dépliage,
    /// le panneau restant en mémoire d'un survol à l'autre et parfois d'un jour à l'autre.
    func refreshWeek() {
        weekStrip.refresh()
        calendarWidget.refresh()
    }

    func select(_ tab: NotchTab, animated: Bool) {
        guard tab != selectedTab else { return }
        selectedTab = tab
        capsule.select(tab, animated: animated)
        applySelection(animated: animated)
        // Seuls les onglets AI et Mirror sont plus hauts : la silhouette et la capsule suivent leur hauteur.
        layoutTabBodies()
        moveCapsuleToSelectedTab(animated: animated)
        if isExpanded { applyShape(expanded: true, animated: animated) }
        updateCameraActivity()
    }

    /// La caméra ne tourne que panneau déplié et onglet Mirror choisi : c'est ce qui éteint le
    /// voyant dès que le panneau se replie ou qu'on change d'onglet.
    private func updateCameraActivity() {
        mirrorTab.setActive(isExpanded && selectedTab == .mirror)
    }

    /// Éteint la caméra sans condition — la fenêtre est retirée, pas seulement repliée.
    func stopCamera() {
        mirrorTab.setActive(false)
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

    // MARK: - Contact

    /// Seule la silhouette peinte répond ; le reste du cadre laisse passer ce qui est dessous.
    ///
    /// Sans cela, un glisser de fichiers destiné à un autre coin du haut de l'écran — une icône
    /// de la barre de menus, par exemple — serait avalé par le grand rectangle invisible de la
    /// fenêtre dès que celle-ci accepte les glissers (`setFileDragActive(_:)`).
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let silhouette else { return super.hitTest(point) }
        let local = convert(point, from: superview)
        // La capsule est hors de la silhouette — c'est tout l'objet de sa forme détachée — donc
        // elle répond pour elle-même, et seulement dépliée : repliée elle est invisible, et rien
        // d'invisible ne doit avaler un clic.
        guard silhouette.contains(local) || (isExpanded && capsuleShape().contains(local)) else { return nil }
        return super.hitTest(point)
    }

    /// Le contour de la capsule, pour le test de contact : son cadre est un rectangle, mais ses
    /// extrémités sont arrondies et ce qui les déborde doit passer dessous.
    private func capsuleShape() -> CGPath {
        let frame = capsuleOnScreenFrame
        let radius = frame.height / 2
        return CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    // MARK: - Dépôt

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard fileTray.canAccept(sender) else { return [] }
        // Un glisser qui arrive sur le panneau vient pour le bac : il passe devant, quel que
        // soit l'onglet affiché jusque-là. C'est aussi ce qui garantit qu'il est bien là, et
        // visible, au moment où le fichier tombe.
        select(.tray, animated: true)
        fileTray.setDropHighlighted(true)
        return .copy
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        fileTray.canAccept(sender) ? .copy : []
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        fileTray.setDropHighlighted(false)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        fileTray.setDropHighlighted(false)
        return fileTray.accept(sender)
    }

    // MARK: - Mise en page

    override func layout() {
        super.layout()

        applyShape(expanded: isExpanded, animated: false)

        // Le panneau n'occupe pas tout le cadre : la bande basse revient à la capsule. Le
        // conteneur, lui, garde le cadre entier — son masque est la silhouette, qui est décrite
        // dans ce repère-là.
        let panel = panelRect
        contentContainer.frame = bounds

        capsule.frame = NotchPanelGeometry.capsuleRect(in: bounds, tab: selectedTab)
        // La place de repos est relevée ici, une fois le cadre posé et avant que l'entrée ou la
        // sortie ne décale le calque : c'est le point d'arrivée de la course, et il ne peut pas
        // être lu plus tard, quand la capsule est justement ailleurs.
        capsuleRestingPosition = capsule.layer?.position ?? .zero
        applyCapsuleReveal(animated: false)

        let wingedWidth = collapsedSize.width + 2 * DeviceStatusPillView.wingWidth
        deviceStatusPill.frame = NSRect(
            x: bounds.midX - wingedWidth / 2,
            y: panel.maxY - collapsedSize.height,
            width: wingedWidth,
            height: collapsedSize.height)

        layoutTabBodies()
    }

    /// Le panneau de l'onglet affiché, dans le repère de cette vue.
    private var panelRect: CGRect {
        NotchPanelGeometry.panelRect(in: bounds, tab: selectedTab)
    }

    /// Corps des onglets : tout l'intérieur du panneau. Les onglets l'occupent en entier et se
    /// relaient dedans. Séparé de `layout()` pour qu'un changement d'onglet puisse le refaire sans
    /// poser sèchement la silhouette, qui s'anime.
    private func layoutTabBodies() {
        let inset = NotchPanelGeometry.contentInsetX
        let panel = panelRect
        let bodyTop = panel.maxY - NotchPanelGeometry.contentInsetTop(forCollapsedHeight: collapsedSize.height)
        let bodyBottom = panel.minY + NotchPanelGeometry.contentInsetBottom
        let body = NSRect(
            x: panel.minX,
            y: bodyBottom,
            width: panel.width,
            height: max(0, bodyTop - bodyBottom)
        ).insetBy(dx: inset, dy: 0)
        for view in tabContentViews {
            view.frame = body
        }

        // Dans le repère de `globalTab`, la semaine prend toute la largeur utile.
        let weekHeight = NotchPanelGeometry.weekStripHeight
        weekStrip.frame = NSRect(
            x: globalTab.bounds.minX,
            y: globalTab.bounds.maxY - weekHeight,
            width: globalTab.bounds.width,
            height: weekHeight
        )

        calendarWidget.frame = calendarTab.bounds

        // Mirror pose son cercle lui-même, contre le bas du panneau : il a donc tout le cadre du
        // panneau Mirror, quel que soit l'onglet affiché.
        mirrorTab.frame = NotchPanelGeometry.panelRect(in: bounds, tab: .mirror)
    }

    /// Descend ou remonte la capsule sous le panneau de l'onglet affiché. Au ressort du
    /// dépliage, puisque la silhouette se redimensionne en même temps.
    private func moveCapsuleToSelectedTab(animated: Bool) {
        guard let layer = capsule.layer else { return }
        let previous = layer.position
        capsule.frame = NotchPanelGeometry.capsuleRect(in: bounds, tab: selectedTab)
        let target = layer.position
        capsuleRestingPosition = target
        guard isExpanded else { return }
        if animated {
            layer.position = previous
            layer.springAnimate(keyPath: "position", to: target, preset: .gentle)
        }
    }

    // MARK: - Entrée et sortie de la capsule

    /// Course de la capsule : ce dont elle est décalée, repliée, sous sa place de repos.
    ///
    /// Elle sort par le **bas** et non vers le panneau : glisser de dessous lui demanderait
    /// qu'elle soit derrière lui dans l'ordre d'affichage, alors qu'elle est posée par-dessus —
    /// elle lui passerait sur le ventre au lieu d'en sortir.
    private static let capsuleTravel: CGFloat = 14

    /// Fait monter la capsule à sa place, ou l'en fait redescendre. Le ressort est celui du
    /// dépliage (`SpringPreset.gentle`) et le fondu celui du contenu : les deux gestes sont
    /// simultanés et doivent se lire comme un seul.
    ///
    /// Posée sèchement quand il n'y a rien à animer — une mise en page doit déjà trouver la
    /// capsule dans son état courant à la première image.
    private func applyCapsuleReveal(animated: Bool) {
        guard let layer = capsule.layer, capsuleRestingPosition != .zero else { return }

        let target = isExpanded
            ? capsuleRestingPosition
            : CGPoint(x: capsuleRestingPosition.x, y: capsuleRestingPosition.y - Self.capsuleTravel)
        let opacity: Float = isExpanded ? 1 : 0

        guard animated else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.position = target
            layer.opacity = opacity
            CATransaction.commit()
            return
        }

        layer.springAnimate(keyPath: "position", to: target, preset: .gentle)
        PanelFold.fade(layer, to: opacity)
    }

    // MARK: - Pastille d'appareil

    func showDeviceStatus(_ status: DeviceStatus) {
        // Dépliée, la silhouette occupe déjà toute la place.
        guard !isExpanded else { return }
        deviceStatusPill.apply(status)
        deviceStatusPill.layoutSubtreeIfNeeded()
        isShowingDeviceStatus = true
        applyShape(expanded: false, animated: true)
        PanelFold.fade(deviceStatusPill.layer!, to: 1)
    }

    func hideDeviceStatus(animated: Bool = true) {
        guard isShowingDeviceStatus else { return }
        isShowingDeviceStatus = false
        applyShape(expanded: isExpanded, animated: animated)
        if let layer = deviceStatusPill.layer {
            if animated { PanelFold.fade(layer, to: 0) } else { layer.opacity = 0 }
        }
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
            in: panelRect,
            anchoredTo: .top,
            size: collapsedSize,
            shoulderRadius: NotchPanelGeometry.collapsedShoulderRadius,
            farRadius: NotchPanelGeometry.collapsedBottomRadius
        )
    }

    /// L'encoche élargie par ses deux ailes — même hauteur, mêmes rayons.
    private func wingedPath() -> CGPath {
        PanelGeometry.silhouette(
            in: panelRect,
            anchoredTo: .top,
            size: NSSize(
                width: collapsedSize.width + 2 * DeviceStatusPillView.wingWidth,
                height: collapsedSize.height),
            shoulderRadius: NotchPanelGeometry.collapsedShoulderRadius,
            farRadius: NotchPanelGeometry.collapsedBottomRadius
        )
    }

    private func expandedPath() -> CGPath {
        // Mirror : un U plus étroit que les autres onglets, dont le fond est le cercle de l'aperçu.
        // Un rayon de la moitié du corps joint les deux coins du bas en demi-cercle, sans changer
        // le nombre de segments : le passage d'un onglet à l'autre reste animable.
        guard selectedTab == .mirror else {
            return PanelGeometry.silhouette(
                in: panelRect,
                anchoredTo: .top,
                shoulderRadius: NotchPanelGeometry.expandedShoulderRadius,
                farRadius: NotchPanelGeometry.expandedBottomRadius
            )
        }
        return PanelGeometry.silhouette(
            in: panelRect,
            anchoredTo: .top,
            size: CGSize(width: NotchPanelGeometry.mirrorSilhouetteWidth, height: panelRect.height),
            shoulderRadius: NotchPanelGeometry.expandedShoulderRadius,
            farRadius: NotchPanelGeometry.mirrorBodyWidth / 2
        )
    }

    // MARK: - Dépliage

    /// Replie ou déplie le panneau. Seule la silhouette s'anime : la fenêtre garde en
    /// permanence le cadre déplié (voir `NotchPanelGeometry.windowFrame`).
    func setExpanded(_ expanded: Bool, animated: Bool) {
        guard expanded != isExpanded else { return }
        isExpanded = expanded
        if expanded { hideDeviceStatus(animated: animated) }
        applyShape(expanded: expanded, animated: animated)
        updateCameraActivity()
    }

    /// Le fond plein et le verre se passent le relais pendant le dépliage : plein replié, verre
    /// déplié. Le fondu est celui du contenu, pour que les deux fonds ne se superposent jamais
    /// à pleine opacité.
    private func applyGlassReveal(expanded: Bool, animated: Bool) {
        glass.frame = bounds
        // Le verre a le cadre entier de la fenêtre, capsule comprise, alors que le panneau n'en
        // occupe que le haut : le dégradé est ramené à la hauteur du panneau, sans quoi il
        // finirait sous la silhouette, dans la bande de la capsule.
        let panelShare = panelRect.height / max(1, bounds.height)
        glass.fadeToGlass(
            from: CGPoint(x: 0.5, y: 1),
            to: CGPoint(x: 0.5, y: 0),
            solidUntil: 0.72 * panelShare,
            clearBy: 0.97 * panelShare
        )
        glass.applyTint(from: OverlayPalette.resolved(for: effectiveAppearance))
        guard let glassLayer = glass.layer else { return }
        if animated {
            PanelFold.fade(glassLayer, to: expanded ? 1 : 0)
            PanelFold.fade(backgroundLayer, to: expanded ? 0 : 1)
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            glassLayer.opacity = expanded ? 1 : 0
            backgroundLayer.opacity = expanded ? 0 : 1
            CATransaction.commit()
        }
    }

    private func applyShape(expanded: Bool, animated: Bool) {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let path = expanded ? expandedPath() : (isShowingDeviceStatus ? wingedPath() : collapsedPath())
        // La forme visée, et non celle de l'image en cours : pendant le dépliage, c'est déjà sur
        // le panneau déplié qu'on vient cliquer ou déposer.
        silhouette = path

        // Le contenu suit le dépliage en fondu plutôt qu'au ressort, et il est découpé par la
        // silhouette elle-même (`contentMask`) : pendant le dépliage il ne doit rien dépasser de
        // la forme, qui est encore plus étroite que lui.
        // La capsule ne se contente pas de suivre le fondu du contenu : elle monte à sa place et
        // y redescend, puisqu'elle est la seule surface à ne pas être portée par la silhouette.
        applyCapsuleReveal(animated: animated)
        applyGlassReveal(expanded: expanded, animated: animated)

        PanelFold.apply(
            path: path,
            to: [backgroundLayer, glass.shapeMask, strokeLayer, contentMask],
            in: bounds,
            fading: contentContainer.layer.map { [$0] } ?? [],
            to: expanded ? 1 : 0,
            animated: animated
        )
    }
}

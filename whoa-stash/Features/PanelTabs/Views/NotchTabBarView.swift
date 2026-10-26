import AppKit

/// Barre haute du panneau : les trois onglets collés à gauche, l'engrenage des Préférences à
/// l'extrémité droite.
///
/// L'onglet actif porte une pastille sombre — un seul calque, partagé par tous les onglets, qui
/// **se déplace** d'un onglet à l'autre sur un ressort plutôt que d'apparaître et disparaître.
/// C'est ce glissement qui relie visuellement les deux onglets, et il impose que la pastille soit
/// un calque de la barre et non de l'onglet.
///
/// Contrairement au reste du panneau, cette vue reçoit de vrais événements de souris : la fenêtre
/// ne les laisse plus passer (voir `SidePanelWindow`), parce qu'un onglet se clique.
final class NotchTabBarView: NSView {

    /// Appelé au clic sur un onglet, y compris celui déjà actif — le contrôleur du contenu décide
    /// quoi en faire.
    var onSelect: ((NotchTab) -> Void)?

    /// Appelé au clic sur l'engrenage.
    var onOpenSettings: (() -> Void)?

    private let pillLayer = CALayer()
    private let items: [NotchTabItemView]
    private let gearButton = NotchGearButtonView()

    private var selectedTab: NotchTab

    init(selectedTab: NotchTab) {
        self.selectedTab = selectedTab
        items = NotchTab.allCases.map(NotchTabItemView.init(tab:))
        super.init(frame: .zero)
        wantsLayer = true
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        // Ajoutée avant les onglets : la pastille doit rester *derrière* les icônes et les
        // intitulés, et l'ordre des sous-calques suit l'ordre d'ajout.
        pillLayer.cornerCurve = .continuous
        layer?.addSublayer(pillLayer)

        for item in items {
            item.onClick = { [weak self] tab in self?.onSelect?(tab) }
            addSubview(item)
        }

        gearButton.onClick = { [weak self] in self?.onOpenSettings?() }
        addSubview(gearButton)

        applyPalette()
        applySelection(animated: false)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPalette()
    }

    private func applyPalette() {
        let palette = OverlayPalette.resolved(for: effectiveAppearance)
        pillLayer.backgroundColor = palette.tabPillFill
        items.forEach { $0.applyPalette(palette) }
        gearButton.applyPalette(palette)
    }

    func select(_ tab: NotchTab, animated: Bool) {
        guard tab != selectedTab else { return }
        selectedTab = tab
        applySelection(animated: animated)
    }

    /// Place la pastille sous l'onglet actif et met les contenus au bon niveau de présence. La
    /// pastille n'est animée que lorsqu'elle a déjà une position à quitter — au premier passage,
    /// comme après une remise en page, elle est posée d'emblée.
    private func applySelection(animated: Bool) {
        for item in items {
            item.setActive(item.tab == selectedTab)
        }

        guard let active = items.first(where: { $0.tab == selectedTab }) else { return }
        let target = pillFrame(for: active)

        guard animated, !pillLayer.frame.isEmpty else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            pillLayer.frame = target
            pillLayer.cornerRadius = target.height / 2
            CATransaction.commit()
            return
        }

        // La pastille change de largeur en même temps que de place — « Global » et « AI » n'ont
        // pas le même intitulé — donc les deux propriétés sont animées, pas seulement la position.
        pillLayer.cornerRadius = target.height / 2
        pillLayer.springAnimate(
            keyPath: "position",
            to: CGPoint(x: target.midX, y: target.midY),
            preset: .gentle
        )
        pillLayer.springAnimate(
            keyPath: "bounds",
            to: CGRect(origin: .zero, size: target.size),
            preset: .gentle
        )
    }

    /// Pastille centrée verticalement sur l'onglet, un peu plus basse que la rangée.
    private func pillFrame(for item: NotchTabItemView) -> CGRect {
        let height = TabBarMetrics.pillHeight
        return CGRect(
            x: item.frame.minX,
            y: item.frame.midY - height / 2,
            width: item.frame.width,
            height: height
        )
    }

    /// Pose la rangée d'onglets dans la place que l'engrenage lui laisse, puis l'engrenage.
    ///
    /// La rangée est resserrée plutôt que rognée quand elle est à l'étroit : chaque onglet garde
    /// la largeur de son intitulé, mesurée en gras et sur une seule ligne, et ce sont l'écart
    /// entre onglets d'abord, les marges des pastilles ensuite, qui cèdent. En deçà, la rangée
    /// déborde — un intitulé n'est jamais ni replié ni rogné.
    override func layout() {
        super.layout()

        let count = CGFloat(items.count)
        let available = max(0, bounds.width - TabBarMetrics.gearButtonSize - TabBarMetrics.gearGap)

        // Largeur incompressible : les intitulés, leurs glyphes, et les marges minimales.
        let incompressible = items.reduce(0) { $0 + $1.minimumWidth }
        let paddingSlack = 2 * count * (TabBarMetrics.pillHorizontalPadding - TabBarMetrics.pillMinimumHorizontalPadding)
        let spacingSlack = max(0, count - 1) * TabBarMetrics.tabSpacing

        // Le reste est rendu aux marges d'abord, aux écarts ensuite : à l'étroit, les pastilles
        // se rapprochent avant de se serrer autour de leur contenu.
        let slack = max(0, available - incompressible)
        let padding = TabBarMetrics.pillMinimumHorizontalPadding + min(paddingSlack, slack) / (2 * count)
        let spacing = count > 1
            ? min(spacingSlack, max(0, slack - paddingSlack)) / (count - 1)
            : 0

        var x = bounds.minX
        for item in items {
            item.horizontalPadding = padding
            item.frame = NSRect(x: x, y: bounds.minY, width: item.preferredWidth, height: bounds.height)
            x += item.frame.width + spacing
        }

        let gear = TabBarMetrics.gearButtonSize
        gearButton.frame = NSRect(
            x: bounds.maxX - gear,
            y: bounds.midY - gear / 2,
            width: gear,
            height: gear
        )

        // Les cadres des onglets viennent de changer : la pastille doit les suivre sans rejouer
        // le glissement, qui n'a de sens qu'au changement d'onglet.
        applySelection(animated: false)
    }
}

// MARK: - Un onglet

/// Un onglet de la barre : son glyphe et son intitulé, côte à côte. Ne dessine pas la pastille —
/// elle appartient à la barre, qui la fait glisser d'un onglet à l'autre.
private final class NotchTabItemView: NSView {

    let tab: NotchTab
    var onClick: ((NotchTab) -> Void)?

    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private var palette = OverlayPalette.resolved(for: .currentDrawing())
    private var isActive = false

    init(tab: NotchTab) {
        self.tab = tab
        super.init(frame: .zero)
        wantsLayer = true
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        let configuration = NSImage.SymbolConfiguration(
            pointSize: TabBarMetrics.iconSize,
            weight: .semibold
        )
        iconView.image = NSImage(systemSymbolName: tab.symbolName, accessibilityDescription: tab.title)?
            .withSymbolConfiguration(configuration)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        label.stringValue = tab.title
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        // Un intitulé d'onglet tient sur une ligne, quelle que soit la place qu'on lui laisse :
        // la barre resserre la rangée, elle ne la replie pas.
        label.usesSingleLineMode = true
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byClipping
        addSubview(label)

        applyContentStyle()
    }

    func applyPalette(_ palette: OverlayPalette) {
        self.palette = palette
        applyContentStyle()
    }

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        applyContentStyle()
    }

    /// L'onglet actif passe en gras et prend la teinte franche ; les autres restent en graisse
    /// normale et en retrait. La graisse changeant la largeur du texte, la barre est invitée à se
    /// remettre en page — sinon la pastille ne collerait plus à l'intitulé.
    private func applyContentStyle() {
        let size = NSFont.systemFontSize(for: .small)
        label.font = .systemFont(ofSize: size, weight: isActive ? .bold : .regular)
        label.textColor = isActive ? palette.tabActiveContent : palette.tabInactiveContent
        iconView.contentTintColor = isActive ? palette.tabActiveContent : palette.tabInactiveContent
        invalidateIntrinsicContentSize()
        superview?.needsLayout = true
        needsLayout = true
    }

    /// Marges de la pastille de part et d'autre du couple icône + intitulé. La barre les réduit,
    /// jusqu'à `TabBarMetrics.pillMinimumHorizontalPadding`, quand la rangée est à l'étroit.
    var horizontalPadding = TabBarMetrics.pillHorizontalPadding {
        didSet {
            guard horizontalPadding != oldValue else { return }
            invalidateIntrinsicContentSize()
            needsLayout = true
        }
    }

    /// Largeur réclamée : les deux marges de la pastille autour du couple icône + intitulé.
    var preferredWidth: CGFloat {
        2 * horizontalPadding
            + TabBarMetrics.iconSize
            + TabBarMetrics.iconLabelGap
            + labelWidth
    }

    /// Largeur en deçà de laquelle l'intitulé serait rogné : la même, aux marges minimales.
    var minimumWidth: CGFloat {
        2 * TabBarMetrics.pillMinimumHorizontalPadding
            + TabBarMetrics.iconSize
            + TabBarMetrics.iconLabelGap
            + labelWidth
    }

    /// Largeur de l'intitulé, toujours mesurée en gras quel que soit l'état de l'onglet : c'est
    /// la graisse la plus large, donc celle qui fixe la place à réserver. Sans quoi la largeur de
    /// l'onglet — et la place de ses voisins — bougerait quand il devient actif, et son intitulé
    /// serait rogné au passage en gras.
    private var labelWidth: CGFloat {
        let bold = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .bold)
        return ceil((tab.title as NSString).size(withAttributes: [.font: bold]).width)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: preferredWidth, height: TabBarMetrics.barHeight)
    }

    override func layout() {
        super.layout()

        let icon = TabBarMetrics.iconSize
        iconView.frame = NSRect(
            x: horizontalPadding,
            y: bounds.midY - icon / 2,
            width: icon,
            height: icon
        )

        // Largeur prise à la mesure en gras et non à `intrinsicContentSize`, qui suit la graisse
        // du moment : l'intitulé garde ainsi son cadre d'un état à l'autre.
        let labelHeight = label.intrinsicContentSize.height
        label.frame = NSRect(
            x: iconView.frame.maxX + TabBarMetrics.iconLabelGap,
            y: bounds.midY - labelHeight / 2,
            width: labelWidth,
            height: labelHeight
        )
    }

    /// Le glyphe et l'intitulé sont des sous-vues, et ce sont elles que la pile de vues
    /// désignerait au clic — un `NSTextField` non éditable reste cliquable. L'onglet répond donc
    /// lui-même pour tout son cadre, sans quoi `mouseUp` irait au libellé, qui l'ignore.
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        // Rien au `mouseDown` : l'onglet ne bascule qu'au relâché, et seulement si le curseur est
        // encore dessus — un clic amorcé puis emmené ailleurs ne doit pas changer d'onglet.
    }

    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard bounds.contains(location) else { return }
        onClick?(tab)
    }
}

// MARK: - Engrenage

/// Bouton des Préférences à l'extrémité droite de la barre. Un simple glyphe qui s'éclaircit au
/// survol — pas de pastille, pour ne pas concurrencer celle de l'onglet actif.
private final class NotchGearButtonView: NSView {

    var onClick: (() -> Void)?

    private let iconView = NSImageView()
    private var palette = OverlayPalette.resolved(for: .currentDrawing())
    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        let configuration = NSImage.SymbolConfiguration(
            pointSize: TabBarMetrics.gearIconSize,
            weight: .medium
        )
        iconView.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")?
            .withSymbolConfiguration(configuration)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        applyTint()
    }

    func applyPalette(_ palette: OverlayPalette) {
        self.palette = palette
        applyTint()
    }

    private func applyTint() {
        iconView.contentTintColor = isHovered ? palette.tabActiveContent : palette.tabInactiveContent
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        applyTint()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        applyTint()
    }

    override func layout() {
        super.layout()
        let icon = TabBarMetrics.gearIconSize
        iconView.frame = NSRect(
            x: bounds.midX - icon / 2,
            y: bounds.midY - icon / 2,
            width: icon,
            height: icon
        )
    }

    /// Même raison que pour un onglet : le glyphe est une sous-vue, et c'est lui que le clic
    /// atteindrait.
    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard bounds.contains(location) else { return }
        onClick?()
    }
}

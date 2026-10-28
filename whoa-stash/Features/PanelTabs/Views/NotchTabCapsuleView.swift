import AppKit

/// Barre de navigation du panneau de l'encoche, posée sous le panneau et détachée de lui : une
/// capsule de verre (Liquid Glass) qui porte les onglets, et à sa droite, **hors** de la capsule,
/// une bulle de verre pour l'engrenage des Préférences. Rien que des glyphes — un onglet ne porte
/// pas son intitulé ici, c'est le cercle qui dit lequel est actif.
///
/// Ce cercle est un seul calque, partagé par tous les onglets, qui **se déplace** d'une bulle à
/// l'autre sur un ressort plutôt que d'apparaître et disparaître. C'est ce glissement qui relie
/// visuellement les deux onglets, et il impose que le cercle soit un calque de la capsule et non
/// de la bulle.
///
/// Comme le reste du panneau déplié, cette vue reçoit de vrais événements de souris : la fenêtre
/// ne les laisse plus passer une fois dépliée (voir `NotchPanelWindow`), parce qu'un onglet se
/// clique. Elle vit hors du conteneur de contenu du panneau, qui est découpé par la silhouette :
/// la capsule est justement ce qui se trouve en dehors.
final class NotchTabCapsuleView: NSView {

    /// Appelé au clic sur un onglet, y compris celui déjà actif — le contrôleur du contenu décide
    /// quoi en faire.
    var onSelect: ((NotchTab) -> Void)?

    /// Appelé au clic sur l'engrenage.
    var onOpenSettings: (() -> Void)?

    private let circleLayer = CALayer()
    private let items: [NotchTabBubbleView]
    private let gearButton = NotchGearButtonView()

    /// Le conteneur de verre rend les deux surfaces en une passe ; son espacement reste à zéro,
    /// sans quoi la capsule et la bulle fusionneraient en une seule forme.
    private let container = NSGlassEffectContainerView()
    private let holder = NSView()
    private let tabsGlass = NSGlassEffectView()
    private let tabsContent = NSView()
    private let settingsGlass = NSGlassEffectView()

    private var selectedTab: NotchTab

    /// Largeur de la capsule seule : les bulles des onglets, leurs écarts et les deux marges.
    static var tabsWidth: CGFloat {
        let count = CGFloat(NotchTab.allCases.count)
        return 2 * TabBarMetrics.capsuleHorizontalPadding
            + count * TabBarMetrics.bubbleSize
            + max(0, count - 1) * TabBarMetrics.bubbleSpacing
    }

    /// Largeur de la barre entière : la capsule, l'écart, puis la bulle des Préférences, ronde à
    /// la hauteur de la capsule. Une constante — rien de ce qu'elle porte ne change de taille —,
    /// dont le panneau se sert pour centrer la barre sous lui.
    static var width: CGFloat {
        tabsWidth + TabBarMetrics.gearBubbleGap + TabBarMetrics.capsuleHeight
    }

    init(selectedTab: NotchTab) {
        self.selectedTab = selectedTab
        items = NotchTab.allCases.map(NotchTabBubbleView.init(tab:))
        super.init(frame: .zero)
        wantsLayer = true
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        container.contentView = holder
        addSubview(container)
        holder.addSubview(tabsGlass)
        holder.addSubview(settingsGlass)

        // Tout ce que porte la capsule vit dans le `contentView` de son verre — le seul
        // emplacement dont `NSGlassEffectView` garantit qu'il est posé dans l'effet.
        // Le cercle est ajouté avant les bulles : il doit rester *derrière* les glyphes, et
        // l'ordre des sous-calques suit l'ordre d'ajout.
        tabsContent.wantsLayer = true
        circleLayer.cornerCurve = .continuous
        tabsContent.layer?.addSublayer(circleLayer)
        tabsGlass.contentView = tabsContent

        for item in items {
            item.onClick = { [weak self] tab in self?.onSelect?(tab) }
            tabsContent.addSubview(item)
        }

        gearButton.onClick = { [weak self] in self?.onOpenSettings?() }
        settingsGlass.contentView = gearButton

        applyPalette()
        applySelection(animated: false)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPalette()
    }

    private func applyPalette() {
        let palette = OverlayPalette.resolved(for: effectiveAppearance)
        circleLayer.backgroundColor = palette.tabCircleFill
        items.forEach { $0.applyPalette(palette) }
        gearButton.applyPalette(palette)
    }

    func select(_ tab: NotchTab, animated: Bool) {
        guard tab != selectedTab else { return }
        selectedTab = tab
        applySelection(animated: animated)
    }

    /// Place le cercle sous l'onglet actif et met les glyphes au bon niveau de présence. Le
    /// cercle n'est animé que lorsqu'il a déjà une position à quitter — au premier passage, comme
    /// après une remise en page, il est posé d'emblée.
    private func applySelection(animated: Bool) {
        for item in items {
            item.setActive(item.tab == selectedTab)
        }

        guard let active = items.first(where: { $0.tab == selectedTab }) else { return }
        let target = active.frame

        guard animated, !circleLayer.frame.isEmpty else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            circleLayer.frame = target
            circleLayer.cornerRadius = target.height / 2
            CATransaction.commit()
            return
        }

        // Toutes les bulles ont la même taille : seule la position change d'un onglet à l'autre,
        // et c'est la seule propriété à porter au ressort.
        circleLayer.springAnimate(
            keyPath: "position",
            to: CGPoint(x: target.midX, y: target.midY),
            preset: .gentle
        )
    }

    /// Pose la capsule à gauche et la bulle des Préférences à sa droite, puis la rangée de
    /// bulles dans la capsule. Rien ne se resserre : la barre reçoit exactement la largeur que
    /// `width` annonce.
    override func layout() {
        super.layout()

        container.frame = bounds
        holder.frame = bounds

        let height = bounds.height
        tabsGlass.frame = NSRect(x: 0, y: 0, width: Self.tabsWidth, height: height)
        tabsGlass.cornerRadius = height / 2
        settingsGlass.frame = NSRect(
            x: Self.tabsWidth + TabBarMetrics.gearBubbleGap,
            y: 0,
            width: height,
            height: height
        )
        settingsGlass.cornerRadius = height / 2
        tabsContent.frame = tabsGlass.bounds

        let size = TabBarMetrics.bubbleSize
        let y = tabsContent.bounds.midY - size / 2
        var x = TabBarMetrics.capsuleHorizontalPadding

        for item in items {
            item.frame = NSRect(x: x, y: y, width: size, height: size)
            x += size + TabBarMetrics.bubbleSpacing
        }

        // Les cadres des bulles viennent de changer : le cercle doit les suivre sans rejouer le
        // glissement, qui n'a de sens qu'au changement d'onglet.
        applySelection(animated: false)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.width, height: TabBarMetrics.capsuleHeight)
    }
}

// MARK: - Une bulle

/// La bulle d'un onglet : son glyphe, seul et centré. Ne dessine pas le cercle — il appartient à
/// la capsule, qui le fait glisser d'une bulle à l'autre.
private final class NotchTabBubbleView: NSView {

    let tab: NotchTab
    var onClick: ((NotchTab) -> Void)?

    private let iconView = NSImageView()
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

    /// Le glyphe de l'onglet actif est posé **sur** le cercle d'accent, et prend donc la teinte
    /// qui contraste avec lui ; les autres restent en retrait, à même la capsule.
    private func applyContentStyle() {
        iconView.contentTintColor = isActive ? palette.tabPillContent : palette.tabInactiveContent
    }

    override func layout() {
        super.layout()
        let icon = TabBarMetrics.iconSize
        iconView.frame = NSRect(
            x: bounds.midX - icon / 2,
            y: bounds.midY - icon / 2,
            width: icon,
            height: icon
        )
    }

    /// Le glyphe est une sous-vue, et c'est lui que la pile de vues désignerait au clic. La bulle
    /// répond donc elle-même pour tout son cadre, sans quoi `mouseUp` irait à l'image, qui
    /// l'ignore.
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

/// Bouton des Préférences, posé dans sa propre bulle de verre à droite de la capsule. Un simple
/// glyphe qui s'éclaircit au survol — la bulle de verre est son seul fond.
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
            pointSize: TabBarMetrics.iconSize,
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
        let icon = TabBarMetrics.iconSize
        iconView.frame = NSRect(
            x: bounds.midX - icon / 2,
            y: bounds.midY - icon / 2,
            width: icon,
            height: icon
        )
    }

    /// Même raison que pour une bulle : le glyphe est une sous-vue, et c'est lui que le clic
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

import AppKit
import CoreGraphics
import OSLog

/// Fenêtre flottante collée au bord droit du vrai Dock : même hauteur, même matériau, mêmes
/// coins, même niveau de fenêtre que le Dock (`CGWindowLevelForKey(.dockWindow)`). La
/// révélation se fait par un masque `CALayer` qui s'étend de gauche à droite (jamais un simple
/// fade), et la disparition par l'animation inverse.
final class DockExtensionWindow {

    var onIconClicked: ((ResolvedDockSlot) -> Void)?

    private let panel: NSPanel
    private let contentView: DockExtensionContentView
    private let maskLayer = CALayer()

    private var iconViews: [DockExtensionIconView] = []
    private var isRevealed = false
    private var currentSide: EdgePosition = .right

    private let revealDuration: TimeInterval = 0.32
    private let hideDuration: TimeInterval = 0.26
    private let revealCurve = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)

    /// Petit espace constant entre le Dock système et l'extension — assez discret pour que les
    /// deux soient perçus comme liés, mais visuellement distincts (au lieu d'être soudés).
    private let dockGap: CGFloat = 6
    /// Rayon de coin exprimé en fraction de la hauteur du Dock plutôt qu'une constante fixe :
    /// le vrai Dock garde une proportion coin/hauteur stable quelle que soit la taille des icônes.
    private let cornerRadiusRatio: CGFloat = 0.28

    init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        contentView = DockExtensionContentView()
        panel.contentView = contentView

        maskLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
        maskLayer.backgroundColor = NSColor.black.cgColor
        contentView.layer?.mask = maskLayer

        Log.dockExtension.debug("window: init() — panel créé, level=\(self.panel.level.rawValue, privacy: .public) (CGWindowLevelForKey(.dockWindow)=\(CGWindowLevelForKey(.dockWindow), privacy: .public))")
    }

    /// Reconstruit les icônes affichées ; n'affecte pas la visibilité en cours (le
    /// contrôleur appelle `reveal`/`hide` séparément selon la géométrie du Dock).
    func setSlots(_ slots: [ResolvedDockSlot], tileSize: CGFloat) {
        Log.dockExtension.debug("window: setSlots() — \(slots.count, privacy: .public) slot(s): \(slots.map { $0.name }.description), tileSize=\(tileSize, privacy: .public)")
        iconViews.forEach { $0.removeFromSuperview() }
        iconViews = slots.map { slot in
            let icon = DockExtensionIconView(slot: slot, tileSize: tileSize)
            icon.onClick = { [weak self] clicked in self?.onIconClicked?(clicked) }
            return icon
        }
        contentView.configure(icons: iconViews, tileSize: tileSize)
    }

    /// Repositionne la fenêtre contre le Dock sans rejouer l'animation d'apparition —
    /// utilisé quand le Dock bouge (ou que le côté change) pendant que l'extension est déjà
    /// affichée.
    func reposition(against geometry: DockGeometry, side: EdgePosition) {
        currentSide = side
        let frame = windowFrame(for: geometry, side: side)
        Log.dockExtension.debug("window: reposition() — frame=\(String(describing: frame), privacy: .public), side=\(side.rawValue, privacy: .public)")
        contentView.cornerRadius = geometry.frame.height * cornerRadiusRatio
        panel.setFrame(frame, display: true)
        contentView.frame = NSRect(origin: .zero, size: frame.size)
        maskLayer.anchorPoint = anchorPoint(for: side)
        if isRevealed {
            applyMask(width: frame.size.width)
        }
    }

    func reveal(against geometry: DockGeometry, side: EdgePosition) {
        Log.dockExtension.debug("window: reveal() appelé — isRevealed=\(self.isRevealed, privacy: .public), iconViews.count=\(self.iconViews.count, privacy: .public), side=\(side.rawValue, privacy: .public)")
        guard !isRevealed else {
            reposition(against: geometry, side: side)
            return
        }

        currentSide = side
        let frame = windowFrame(for: geometry, side: side)
        Log.dockExtension.debug("window: reveal() — frame calculé=\(String(describing: frame), privacy: .public), panel.isVisible avant=\(self.panel.isVisible, privacy: .public)")
        contentView.cornerRadius = geometry.frame.height * cornerRadiusRatio
        panel.setFrame(frame, display: true)
        contentView.frame = NSRect(origin: .zero, size: frame.size)

        maskLayer.anchorPoint = anchorPoint(for: side)
        applyMask(width: 0)

        panel.alphaValue = 1
        panel.orderFrontRegardless()
        panel.ignoresMouseEvents = false
        isRevealed = true
        Log.dockExtension.debug("window: reveal() — orderFrontRegardless() exécuté, panel.isVisible après=\(self.panel.isVisible, privacy: .public), frame réel=\(String(describing: self.panel.frame), privacy: .public)")

        animateMaskWidth(to: frame.size.width, duration: revealDuration)
        contentView.revealIcons(duration: revealDuration)
    }

    func hide() {
        Log.dockExtension.debug("window: hide() appelé — isRevealed=\(self.isRevealed, privacy: .public)")
        guard isRevealed else { return }
        isRevealed = false
        panel.ignoresMouseEvents = true

        contentView.hideIcons(duration: hideDuration)
        animateMaskWidth(to: 0, duration: hideDuration) { [weak self] in
            guard let self, !self.isRevealed else { return }
            Log.dockExtension.debug("window: hide() — animation terminée, orderOut(nil)")
            self.panel.orderOut(nil)
        }
    }

    /// Bord de la fenêtre qui touche le Dock (`0` = gauche, `1` = droite) : c'est ce bord qui
    /// reste fixe pendant le dépliage, la largeur grandissant vers le bord opposé.
    private func anchorPoint(for side: EdgePosition) -> CGPoint {
        CGPoint(x: side == .right ? 0 : 1, y: 0.5)
    }

    private func windowFrame(for geometry: DockGeometry, side: EdgePosition) -> NSRect {
        // Le gap fait partie de la position de départ de la fenêtre, pas de l'animation : la
        // largeur du masque grandit à l'intérieur de ce frame déjà décalé, donc l'espacement
        // avec le Dock reste constant du début à la fin du dépliage.
        let desiredWidth = contentView.desiredWidth(for: iconViews.count, tileSize: geometry.tileSize)

        let originX: CGFloat
        let width: CGFloat
        switch side {
        case .right:
            let candidateOriginX = geometry.frame.maxX + dockGap
            let availableWidth = max(0, geometry.screen.frame.maxX - candidateOriginX)
            width = min(desiredWidth, availableWidth)
            originX = candidateOriginX
        case .left:
            let availableWidth = max(0, geometry.frame.minX - dockGap - geometry.screen.frame.minX)
            width = min(desiredWidth, availableWidth)
            originX = geometry.frame.minX - dockGap - width
        }

        Log.dockExtension.debug("window: windowFrame() — dockFrame=\(String(describing: geometry.frame), privacy: .public), gap=\(self.dockGap, privacy: .public), side=\(side.rawValue, privacy: .public), screen=\(String(describing: geometry.screen.frame), privacy: .public), desiredWidth=\(desiredWidth, privacy: .public), width final=\(width, privacy: .public)")
        return NSRect(x: originX, y: geometry.frame.minY, width: width, height: geometry.frame.height)
    }

    /// Met à jour `bounds`/`position` du masque pour une largeur donnée, en tenant compte du
    /// bord d'ancrage courant (`currentSide`) — le bord touchant le Dock reste fixe.
    private func applyMask(width: CGFloat) {
        let height = contentView.bounds.height
        let totalWidth = contentView.bounds.width
        maskLayer.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        maskLayer.position = CGPoint(x: currentSide == .right ? 0 : totalWidth, y: height / 2)
    }

    private func animateMaskWidth(to width: CGFloat, duration: TimeInterval, completion: (() -> Void)? = nil) {
        let fromWidth = maskLayer.presentation()?.bounds.width ?? maskLayer.bounds.width

        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)

        let animation = CABasicAnimation(keyPath: "bounds.size.width")
        animation.fromValue = fromWidth
        animation.toValue = width
        animation.duration = duration
        animation.timingFunction = revealCurve

        applyMask(width: width)
        maskLayer.add(animation, forKey: "widthAnimation")

        CATransaction.commit()
    }
}

/// Contenu visuel de l'extension : même matériau, même hauteur et mêmes coins que le Dock
/// système, avec une bordure discrète — pensé pour être perçu comme un morceau du Dock plutôt
/// que comme une fenêtre flottante indépendante.
private final class DockExtensionContentView: NSView {

    private let visualEffectView = NSVisualEffectView()
    private let strokeLayer = CAShapeLayer()
    private var iconViews: [DockExtensionIconView] = []

    /// Réglé dynamiquement par `DockExtensionWindow` d'après la hauteur réelle du Dock.
    var cornerRadius: CGFloat = 16 {
        didSet {
            guard oldValue != cornerRadius else { return }
            needsLayout = true
        }
    }

    private let spacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 10
    /// < 0.5 pousse les icônes vers le bas de la barre : le vrai Dock réserve plus d'espace
    /// au-dessus des icônes (marge de magnification) qu'en dessous (juste la place du point
    /// d'app active), donc les centrer verticalement les faisait paraître trop hautes.
    private let verticalBias: CGFloat = 0.32

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
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        addSubview(visualEffectView)

        strokeLayer.fillColor = nil
        strokeLayer.lineWidth = 1
        layer?.addSublayer(strokeLayer)
        updateStrokeColor()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStrokeColor()
    }

    private func updateStrokeColor() {
        strokeLayer.strokeColor = OverlayPalette.resolved(for: effectiveAppearance).strokeColor
    }

    // Layout entièrement manuel (frames), comme le reste de l'overlay (`BrightnessBarView` etc.) —
    // pas de NSStackView : le mélanger avec des frames imposées depuis `layout()` provoquait un
    // conflit de contraintes et un appel réentrant à layoutSubtreeIfNeeded (logué par AppKit),
    // qui pouvait laisser les icônes à taille nulle.
    override func layout() {
        super.layout()

        visualEffectView.frame = bounds
        visualEffectView.layer?.cornerRadius = cornerRadius
        visualEffectView.layer?.cornerCurve = .continuous
        visualEffectView.layer?.masksToBounds = true

        strokeLayer.path = CGPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )

        layoutIcons()
    }

    private func layoutIcons() {
        var x = horizontalPadding
        for icon in iconViews {
            let size = icon.frame.size
            icon.frame = NSRect(x: x, y: (bounds.height - size.height) * verticalBias, width: size.width, height: size.height)
            x += size.width + spacing
        }
    }

    func desiredWidth(for iconCount: Int, tileSize: CGFloat) -> CGFloat {
        guard iconCount > 0 else { return 0 }
        return CGFloat(iconCount) * tileSize + CGFloat(iconCount - 1) * spacing + horizontalPadding * 2
    }

    func configure(icons: [DockExtensionIconView], tileSize: CGFloat) {
        iconViews.forEach { $0.removeFromSuperview() }
        iconViews = icons
        iconViews.forEach { addSubview($0) }
        layoutIcons()
    }

    func revealIcons(duration: TimeInterval) {
        animateIcons(appearing: true, totalDuration: duration)
    }

    func hideIcons(duration: TimeInterval) {
        animateIcons(appearing: false, totalDuration: duration)
    }

    /// Fait apparaître/disparaître chaque icône avec un délai croissant selon sa position
    /// horizontale, pour suivre le bord du masque plutôt que de sauter d'un coup.
    private func animateIcons(appearing: Bool, totalDuration: TimeInterval) {
        let icons = iconViews
        guard !icons.isEmpty else { return }

        let iconDuration = 0.18
        let maxDelay = max(0, totalDuration - iconDuration)

        for (index, icon) in icons.enumerated() {
            guard let layer = icon.layer else { continue }
            let progress: CGFloat = icons.count > 1 ? CGFloat(index) / CGFloat(icons.count - 1) : 0
            let delay = appearing ? Double(progress) * maxDelay : Double(1 - progress) * maxDelay

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.opacity = appearing ? 1 : 0
            CATransaction.commit()

            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = appearing ? 0 : 1
            animation.toValue = appearing ? 1 : 0
            animation.duration = iconDuration
            animation.beginTime = CACurrentMediaTime() + delay
            animation.fillMode = .backwards
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(animation, forKey: "iconFade")
        }
    }
}

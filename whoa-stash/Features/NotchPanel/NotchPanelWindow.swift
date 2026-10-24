import AppKit

/// Fenêtre flottante du panneau de l'encoche, une par écran. Jumelle de `SidePanelWindow` : elle
/// ne prend jamais le focus, n'apparaît pas dans le Dock (l'app est déjà `LSUIElement`) et laisse
/// passer tous les clics, le survol étant déduit de la position globale du curseur par
/// `NotchPanelController`.
///
/// Deux choses la distinguent de la bande du bord droit :
///
/// - elle reste **affichée en permanence**, parce que l'état replié se voit : il épouse
///   l'encoche sur les Macs qui en ont une, et prend la forme d'une pastille sur les autres ;
/// - son cadre ne change jamais — il vaut toujours le cadre déplié — et c'est la silhouette
///   dessinée à l'intérieur qui s'anime.
@MainActor
final class NotchPanelWindow {

    private let panel: NSPanel
    private let contentView = NotchPanelContentView()

    init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // Voir `NotchPanelContentView` : l'ombre est portée par le calque du contenu.
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        // Toujours sombre, contrairement aux autres panneaux de l'overlay qui suivent le réglage
        // Général > Appearance : replié, celui-ci doit se confondre avec le noir matériel de
        // l'encoche, qu'une palette claire trahirait immédiatement.
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = contentView
    }

    var frame: NSRect { panel.frame }
    var isExpanded: Bool { contentView.isExpanded }

    func apply(usageState: ClaudeUsageState, animated: Bool) {
        contentView.apply(usageState: usageState, animated: animated)
    }

    var ringCount: Int { contentView.ringCount }

    /// Cadre d'une bague en coordonnées globales AppKit, le repère dans lequel raisonnent
    /// `NotchPanelGeometry` et `NotchPanelController`. La vue de contenu remplit la fenêtre, donc
    /// un simple décalage suffit.
    func ringScreenRect(at index: Int) -> NSRect? {
        guard let frame = contentView.ringFrame(at: index) else { return nil }
        return frame.offsetBy(dx: panel.frame.minX, dy: panel.frame.minY)
    }

    func setHighlightedRing(_ index: Int?) {
        contentView.setHighlightedRing(index)
    }

    /// Pose la fenêtre sur son écran et l'affiche repliée. Appelé à la construction et à chaque
    /// changement de configuration d'écrans.
    func place(on screen: NSScreen) {
        let frame = NotchPanelGeometry.windowFrame(on: screen)
        panel.setFrame(frame, display: true)
        contentView.frame = NSRect(origin: .zero, size: frame.size)
        contentView.collapsedSize = NotchPanelGeometry.collapsedSize(on: screen)
        contentView.layoutSubtreeIfNeeded()
        panel.orderFrontRegardless()
    }

    func setExpanded(_ expanded: Bool, animated: Bool = true) {
        if !expanded {
            contentView.setHighlightedRing(nil)
        }
        contentView.setExpanded(expanded, animated: animated)
    }

    /// Retrait immédiat : l'écran correspondant vient de disparaître.
    func close() {
        panel.orderOut(nil)
    }
}

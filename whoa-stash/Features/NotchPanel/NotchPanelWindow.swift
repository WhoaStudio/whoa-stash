import AppKit

/// Fenêtre flottante du panneau de l'encoche, une par écran. Jumelle de `SidePanelWindow` : elle
/// ne prend jamais le focus et n'apparaît pas dans le Dock (l'app est déjà `LSUIElement`). Le
/// survol reste déduit de la position globale du curseur par `NotchPanelController`.
///
/// Elle ne prend les clics que **dépliée**, le temps que ses onglets soient là pour les recevoir.
/// Contrairement à la bande du bord droit, qui n'est à l'écran que révélée, celle-ci y est en
/// permanence : les accepter tout le temps lui ferait avaler, repliée, les clics du haut de
/// l'écran — ceux de la barre de menus comprise.
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
        // Repliée, la fenêtre laisse tout passer ; `setExpanded(_:animated:)` ouvre et referme
        // ce robinet. `.nonactivatingPanel` fait que recevoir un clic n'active pas l'app pour
        // autant : celle de devant garde le focus clavier.
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

    /// Relayé jusqu'au contrôleur, qui ouvre les Préférences — ni la fenêtre ni la vue de contenu
    /// n'ont à connaître `SettingsWindowController`.
    var onOpenSettings: (() -> Void)? {
        get { contentView.onOpenSettings }
        set { contentView.onOpenSettings = newValue }
    }

    func apply(usageState: ClaudeUsageState, animated: Bool) {
        contentView.apply(usageState: usageState, animated: animated)
    }

    /// Repeint depuis la palette courante — appelé quand l'accent ou la translucidité change
    /// dans les Préférences, et non quand l'apparence système bascule (AppKit s'en charge).
    func refreshPalette() {
        contentView.refreshOverlayPalette()
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
        if expanded {
            contentView.refreshWeek()
        } else {
            contentView.setHighlightedRing(nil)
            // Le panneau rouvrira sur Global : on ne retrouve pas le bac à fichiers la fois
            // suivante. Sans animation, le repli étant déjà en cours.
            contentView.select(.global, animated: false)
        }
        // Les onglets ne sont cliquables que dépliés — voir la note en tête de type.
        panel.ignoresMouseEvents = !expanded
        contentView.setExpanded(expanded, animated: animated)
    }

    /// Retrait immédiat : l'écran correspondant vient de disparaître.
    func close() {
        panel.orderOut(nil)
    }
}

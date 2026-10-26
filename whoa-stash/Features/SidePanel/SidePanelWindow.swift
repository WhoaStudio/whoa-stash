import AppKit

/// Fenêtre flottante du panneau latéral, une par écran. Ne prend jamais le focus, n'apparaît pas
/// dans le Dock (l'app est déjà `LSUIElement`) et laisse passer tous les clics : rien n'y est
/// cliquable — les onglets et leur engrenage appartiennent au panneau de l'encoche.
///
/// Le survol est déduit de la position globale du curseur par `SidePanelController`, et non de
/// `NSTrackingArea` : il doit continuer de fonctionner pendant que le curseur traverse la bulle,
/// qui est une autre fenêtre.
///
/// Son cadre ne change pas pendant le dépliage — c'est la silhouette dessinée à l'intérieur qui
/// s'anime, comme dans le panneau de l'encoche —, mais contrairement à celui-ci la fenêtre est
/// retirée une fois la bande repliée : rien ne doit rester sur le bord entre deux survols.
@MainActor
final class SidePanelWindow {

    private let panel: NSPanel
    private let contentView = SidePanelContentView()
    private var isRevealed = false

    /// L'apparence est passée à la construction plutôt que lue depuis `SettingsStorage` : le
    /// panneau n'a besoin que de cette valeur, et son propriétaire la tient déjà.
    init(appearanceMode: AppearanceMode) {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // Voir `SidePanelContentView` : l'ombre est portée par le calque du contenu.
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        // Au-dessus des fenêtres plein écran — les niveaux `.statusBar` et Dock utilisés ailleurs
        // dans l'overlay passent dessous.
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.appearance = appearanceMode.nsAppearance
        panel.contentView = contentView
        contentView.anchorEdge = SidePanelGeometry.anchorEdge
    }

    var frame: NSRect { panel.frame }

    func apply(usageState: ClaudeUsageState, animated: Bool) {
        contentView.apply(usageState: usageState, animated: animated)
    }

    /// Suit le réglage Général > Appearance comme les autres panneaux de l'overlay, au lieu de
    /// suivre l'apparence système : c'est lui qui décide si le panneau est anthracite ou clair.
    func apply(appearanceMode: AppearanceMode) {
        panel.appearance = appearanceMode.nsAppearance
    }

    var isVisible: Bool { isRevealed }

    /// Met en avant la bague survolée — le contrôleur la désigne depuis la position du curseur,
    /// la fenêtre ne recevant aucun événement.
    func setHighlightedRing(_ index: Int?) {
        contentView.setHighlightedRing(index)
    }

    var ringCount: Int { contentView.ringCount }

    /// Cadre d'une bague en coordonnées globales AppKit, le repère dans lequel raisonnent
    /// `SidePanelGeometry` et `SidePanelController`. La vue de contenu remplit la fenêtre, donc
    /// un simple décalage suffit.
    func ringScreenRect(at index: Int) -> NSRect? {
        guard let frame = contentView.ringFrame(at: index) else { return nil }
        return frame.offsetBy(dx: panel.frame.minX, dy: panel.frame.minY)
    }

    func reveal(in frame: NSRect) {
        setFrame(frame)
        guard !isRevealed else { return }
        isRevealed = true

        contentView.prepareForReveal()
        panel.orderFrontRegardless()
        contentView.setExpanded(true)
    }

    func hide() {
        guard isRevealed else { return }
        isRevealed = false

        contentView.setExpanded(false) { [weak self] in
            // Un nouveau survol pendant le repli relance `reveal` : dans ce cas il ne faut
            // surtout pas retirer la fenêtre une fois l'ancien dépliage terminé.
            guard let self, !self.isRevealed else { return }
            self.panel.orderOut(nil)
        }
    }

    /// Repositionne sans rejouer le dépliage — utilisé quand l'écran change de taille ou de place
    /// pendant que le panneau est affiché.
    func setFrame(_ frame: NSRect) {
        panel.setFrame(frame, display: true)
        contentView.frame = NSRect(origin: .zero, size: frame.size)
    }

    /// Retrait immédiat, sans animation : l'écran correspondant vient de disparaître.
    func close() {
        isRevealed = false
        panel.orderOut(nil)
    }
}

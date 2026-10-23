import AppKit
import Combine

/// Gère un panneau par écran connecté : le révèle quand le curseur entre dans la zone sensible du
/// coin supérieur droit de l'écran survolé, le masque quand le curseur quitte à la fois cette zone
/// et le panneau. Reconstruit la liste des panneaux à chaque changement de configuration d'écrans
/// (branchement, débranchement, résolution, réagencement).
@MainActor
final class SidePanelController {

    private let mouseMonitor = GlobalMouseMonitor()
    private let storage: SettingsStorage

    /// Indexé par `CGDirectDisplayID` et non par position dans `NSScreen.screens`, qui change dès
    /// qu'un écran est branché ou débranché.
    private var windows: [CGDirectDisplayID: SidePanelWindow] = [:]
    private var activeDisplay: CGDirectDisplayID?

    private var screenObserver: NSObjectProtocol?
    private var appearanceCancellable: AnyCancellable?
    private var pollTimer: Timer?

    private var usageState: ClaudeUsageState = .loading

    /// Ouverture déclenchée par un clic sur la bague du Dock, et non par le survol du coin : le
    /// curseur est alors en bas de l'écran, loin de la zone sensible, donc le suivi normal
    /// refermerait le panneau au premier mouvement. L'épinglage suspend cette logique jusqu'à ce
    /// que l'utilisateur soit venu sur le panneau puis en soit ressorti.
    private var isPinned = false
    private var hasVisitedPinnedPanel = false

    /// Ouverture déclenchée par le survol de la bague du Dock : le panneau prend alors la forme
    /// d'une bulle ancrée au-dessus d'elle, et la zone sensible du coin n'a plus son mot à dire.
    /// `ringRect` est conservé pour pouvoir recadrer la bulle si l'écran change pendant qu'elle
    /// est affichée.
    private var isRingAnchored = false
    private var isHoveringRing = false
    private var ringRect: NSRect = .zero

    /// Délai de grâce entre la sortie du curseur de la bague et la fermeture : il faut pouvoir
    /// traverser les quelques points qui séparent la bague de la pointe sans que la bulle se
    /// referme en chemin. La fenêtre ne reçoit aucun événement (voir `SidePanelWindow`), donc
    /// c'est la position globale du curseur qui tranche.
    private let ringHideGrace: TimeInterval = 0.2
    private var ringHideTimer: Timer?

    /// Les moniteurs d'événements ne se déclenchent qu'au mouvement : si le curseur est téléporté,
    /// ou qu'il quitte la zone pendant un changement de Space, plus aucun événement n'arrive et le
    /// panneau resterait ouvert. Ce rafraîchissement ne tourne que pendant qu'un panneau est visible.
    private let pollInterval: TimeInterval = 0.25

    init(storage: SettingsStorage = .shared) {
        self.storage = storage
    }

    func activate() {
        rebuildWindows()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.rebuildWindows() }
        }

        // Aucune permission d'accessibilité requise : seuls les événements clavier et synthétiques
        // en demandent, pas le suivi des déplacements de souris.
        mouseMonitor.onMove = { [weak self] location in
            self?.handleCursor(at: location)
        }
        mouseMonitor.start()

        appearanceCancellable = storage.$settings
            .map(\.general.appearanceMode)
            .removeDuplicates()
            .sink { [weak self] mode in
                self?.apply(appearanceMode: mode)
            }
    }

    private func apply(appearanceMode: AppearanceMode) {
        windows.values.forEach { $0.apply(appearanceMode: appearanceMode) }
    }

    /// Diffuse le dernier instantané à tous les panneaux, y compris ceux qui ne sont pas visibles :
    /// ils doivent être déjà à jour au moment où ils glissent à l'écran, pas se remplir après coup.
    func apply(usageState newState: ClaudeUsageState) {
        usageState = newState
        windows.values.forEach { $0.apply(usageState: newState, animated: true) }
    }

    /// Ouvre (ou referme) le panneau de l'écran qui contient le curseur — appelé par le clic sur
    /// la bague du Dock.
    func togglePinnedReveal() {
        guard !isPinned else {
            isPinned = false
            hideActive()
            return
        }

        guard
            let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
                ?? NSScreen.main,
            let displayID = screen.displayID,
            let window = windows[displayID]
        else { return }

        if activeDisplay != displayID {
            hideActive()
            activeDisplay = displayID
        }

        isPinned = true
        hasVisitedPinnedPanel = false
        window.apply(usageState: usageState, animated: false)
        window.reveal(in: SidePanelGeometry.panelFrame(on: screen), shape: .screenEdge)
        startPolling()
    }

    // MARK: - Survol de la bague du Dock

    /// Révèle la bulle au-dessus de la bague tant que le curseur est dessus, et la referme une
    /// fois le curseur parti — à moins qu'il ne soit passé sur la bulle elle-même.
    func setRingHover(_ hovering: Bool, ringRect rect: NSRect) {
        isHoveringRing = hovering

        guard hovering else {
            scheduleRingHide()
            return
        }

        cancelRingHide()
        ringRect = rect

        guard
            let screen = NSScreen.screens.first(where: { $0.frame.intersects(rect) }) ?? NSScreen.main,
            let displayID = screen.displayID,
            let window = windows[displayID]
        else { return }

        if activeDisplay != displayID {
            hideActive()
            activeDisplay = displayID
        }

        isRingAnchored = true
        window.apply(usageState: usageState, animated: false)
        window.reveal(in: calloutFrame(on: screen), shape: calloutShape(on: screen))
        startPolling()
    }

    private func calloutFrame(on screen: NSScreen) -> NSRect {
        SidePanelGeometry.calloutFrame(anchoredTo: ringRect, on: screen)
    }

    private func calloutShape(on screen: NSScreen) -> SidePanelContentView.Shape {
        .callout(tailCenterX: SidePanelGeometry.tailCenterX(for: calloutFrame(on: screen), ringRect: ringRect))
    }

    private func scheduleRingHide() {
        guard isRingAnchored, ringHideTimer == nil else { return }
        let timer = Timer(timeInterval: ringHideGrace, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.ringHideTimer = nil
                let location = NSEvent.mouseLocation
                guard !self.isCursorOnRing(at: location), !self.isCursorOverActivePanel else { return }
                self.hideActive()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ringHideTimer = timer
    }

    private func cancelRingHide() {
        ringHideTimer?.invalidate()
        ringHideTimer = nil
    }

    /// `isHoveringRing` seul ne suffit pas : l'extension du Dock disparaît avec le Dock en
    /// masquage automatique, et sa case part alors sans émettre de `mouseExited`. Le drapeau
    /// resterait vrai et la bulle ne se refermerait plus jamais. La position du curseur, elle,
    /// reste juste dans tous les cas.
    private func isCursorOnRing(at location: NSPoint) -> Bool {
        isHoveringRing && ringRect.contains(location)
    }

    private var isCursorOverActivePanel: Bool {
        guard let activeDisplay, let window = windows[activeDisplay] else { return false }
        return window.frame.contains(NSEvent.mouseLocation)
    }

    // MARK: - Suivi du curseur

    private func handleCursor(at location: NSPoint) {
        // La bulle de la bague a ses propres règles : elle ne dépend ni de la zone sensible du
        // coin ni de l'écran sous le curseur, seulement du survol de la bague et du sien.
        if isRingAnchored {
            let overPanel = activeDisplay.flatMap { windows[$0] }?.frame.contains(location) ?? false
            if isCursorOnRing(at: location) || overPanel {
                cancelRingHide()
            } else {
                scheduleRingHide()
            }
            return
        }

        // Un seul écran est testé, celui qui contient le curseur : avec des écrans accolés, le bord
        // droit de l'un recouvre le bord gauche du suivant, et tester toutes les zones ferait
        // apparaître le panneau du mauvais écran.
        guard
            let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }),
            let displayID = screen.displayID,
            let window = windows[displayID]
        else {
            hideActive()
            return
        }

        let inHotZone = SidePanelGeometry.hotZone(on: screen).contains(location)
        // Le panneau reste ouvert tant que le curseur est dessus, pour qu'on puisse l'atteindre
        // depuis la zone sensible sans qu'il se referme en chemin.
        let overPanel = activeDisplay == displayID && window.frame.contains(location)

        if isPinned {
            // Le panneau épinglé ne se referme qu'une fois le curseur venu dessus puis reparti —
            // sinon il disparaîtrait avant même que le pointeur ait quitté le Dock.
            if overPanel {
                hasVisitedPinnedPanel = true
            } else if hasVisitedPinnedPanel {
                isPinned = false
                hideActive()
            }
            return
        }

        guard inHotZone || overPanel else {
            hideActive()
            return
        }

        if activeDisplay != displayID {
            hideActive()
            activeDisplay = displayID
        }
        window.apply(usageState: usageState, animated: false)
        window.reveal(in: SidePanelGeometry.panelFrame(on: screen), shape: .screenEdge)
        startPolling()
    }

    private func hideActive() {
        isPinned = false
        isRingAnchored = false
        cancelRingHide()
        guard let activeDisplay else { return }
        windows[activeDisplay]?.hide()
        self.activeDisplay = nil
        stopPolling()
    }

    // MARK: - Écrans

    private func rebuildWindows() {
        var connected: Set<CGDirectDisplayID> = []

        for screen in NSScreen.screens {
            guard let displayID = screen.displayID else { continue }
            connected.insert(displayID)

            let window: SidePanelWindow
            if let existing = windows[displayID] {
                window = existing
            } else {
                window = SidePanelWindow(appearanceMode: storage.settings.general.appearanceMode)
                windows[displayID] = window
            }

            // Un écran déjà connu a pu changer de taille ou de position ; seul le panneau visible
            // a besoin d'être recadré tout de suite, les autres le seront à leur prochain survol.
            if activeDisplay == displayID {
                window.setFrame(isRingAnchored ? calloutFrame(on: screen) : SidePanelGeometry.panelFrame(on: screen))
            }
        }

        for (displayID, window) in windows where !connected.contains(displayID) {
            window.close()
            windows.removeValue(forKey: displayID)
            if activeDisplay == displayID {
                activeDisplay = nil
                stopPolling()
            }
        }
    }

    // MARK: - Rafraîchissement pendant l'affichage

    private func startPolling() {
        guard pollTimer == nil else { return }
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.handleCursor(at: NSEvent.mouseLocation) }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

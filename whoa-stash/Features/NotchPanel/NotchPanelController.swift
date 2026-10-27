import AppKit
import Combine

/// Gère, par écran connecté, le panneau suspendu au haut de l'écran. Replié il épouse l'encoche
/// matérielle — ou prend la forme d'une pastille sur les Macs qui n'en ont pas — et il se déplie
/// quand le curseur entre dans la zone sensible du haut, puis se replie dès qu'il la quitte sans
/// être passé sur le panneau. Reconstruit la liste des fenêtres à chaque changement de
/// configuration d'écrans.
///
/// Même grammaire que `SidePanelController`, qui pilote le placement du bord droit : les deux
/// panneaux coexistent, chacun avec ses fenêtres et sa géométrie.
@MainActor
final class NotchPanelController {

    // Suit aussi le curseur bouton enfoncé : un glisser de fichiers vers l'encoche doit
    // déplier le panneau comme un survol le ferait, sans quoi il n'y aurait rien pour recevoir
    // le dépôt (voir `handleCursor(at:)`).
    private let mouseMonitor = GlobalMouseMonitor(tracksDrags: true)
    private let storage: SettingsStorage

    /// Indexés par `CGDirectDisplayID` et non par position dans `NSScreen.screens`, qui change
    /// dès qu'un écran est branché ou débranché.
    private var windows: [CGDirectDisplayID: NotchPanelWindow] = [:]
    private var expandedDisplay: CGDirectDisplayID?

    private var screenObserver: NSObjectProtocol?
    private var enabledCancellable: AnyCancellable?
    private var paletteObserver: NSObjectProtocol?
    private var pollTimer: Timer?

    private var usageState: ClaudeUsageState = .loading
    private var isActive = false

    /// Dépliage forcé, hors survol (`--show-notch-panel`) : le curseur est alors n'importe où,
    /// donc le suivi normal replierait le panneau au premier mouvement. L'épinglage suspend
    /// cette logique jusqu'à ce que l'utilisateur soit venu sur le panneau puis en soit ressorti.
    private var isPinned = false
    private var hasVisitedPinnedPanel = false

    private var hoveredRingIndex: Int?

    /// Les moniteurs d'événements ne se déclenchent qu'au mouvement : si le curseur est
    /// téléporté, ou qu'il quitte la zone pendant un changement de Space, plus aucun événement
    /// n'arrive et le panneau resterait déplié. Ce rafraîchissement ne tourne que pendant qu'un
    /// panneau est déplié.
    private let pollInterval: TimeInterval = 0.25

    init(storage: SettingsStorage = .shared) {
        self.storage = storage
    }

    func activate() {
        // Le réglage décide à lui seul de l'existence des fenêtres : désactivé, le panneau ne
        // doit pas même laisser sa silhouette repliée en haut de l'écran.
        enabledCancellable = storage.$settings
            .map(\.notchPanel.enabled)
            .removeDuplicates()
            .sink { [weak self] enabled in
                enabled ? self?.start() : self?.stop()
            }

        // Accent et translucidité ne passent pas par `NSAppearance` : la palette les porte, et
        // c'est à nous de demander la repeinte des fenêtres déjà construites.
        paletteObserver = NotificationCenter.default.addObserver(
            forName: OverlayPalette.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.windows.values.forEach { $0.refreshPalette() } }
        }
    }

    private func start() {
        guard !isActive else { return }
        isActive = true

        rebuildWindows()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.rebuildWindows() }
        }

        // Aucune permission d'accessibilité requise : seuls les événements clavier et
        // synthétiques en demandent, pas le suivi des déplacements de souris.
        mouseMonitor.onMove = { [weak self] location in
            self?.handleCursor(at: location)
        }
        mouseMonitor.start()
    }

    private func stop() {
        guard isActive else { return }
        isActive = false

        mouseMonitor.stop()
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
        stopPolling()

        windows.values.forEach { $0.close() }
        windows.removeAll()
        expandedDisplay = nil
        isPinned = false
        hoveredRingIndex = nil
    }

    /// Diffuse le dernier instantané à toutes les fenêtres, y compris celles qui sont repliées :
    /// elles doivent être déjà à jour au moment où elles se déplient, pas se remplir après coup.
    func apply(usageState newState: ClaudeUsageState) {
        usageState = newState
        windows.values.forEach { $0.apply(usageState: newState, animated: true) }
    }

    /// Déplie (ou replie) le panneau de l'écran qui contient le curseur — appelé par
    /// `--show-notch-panel`.
    func togglePinnedReveal() {
        guard !isPinned else {
            isPinned = false
            collapseActive()
            return
        }

        guard
            let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
                ?? NSScreen.main,
            let displayID = screen.displayID,
            let window = windows[displayID]
        else { return }

        if expandedDisplay != displayID {
            collapseActive()
            expandedDisplay = displayID
        }

        isPinned = true
        hasVisitedPinnedPanel = false
        window.apply(usageState: usageState, animated: false)
        window.setExpanded(true)
        startPolling()
    }

    // MARK: - Suivi du curseur

    private func handleCursor(at location: NSPoint) {
        // Menu contextuel ouvert : le suivi est gelé. Le pointeur descend dans le menu, hors du
        // cadre du panneau, et celui-ci se replierait sous un menu encore ouvert.
        guard !OverlayContextMenu.shared.isPresenting else { return }

        // Un fichier en train d'être sorti du bac : le suivi est gelé pour la même raison. Le
        // curseur emmène le fichier loin du panneau, qui se refermerait sous la main.
        guard !FileShelfStore.shared.isDraggingOut else { return }

        // Tous les écrans, et pas seulement celui du curseur : un glisser traverse les écrans, et
        // le panneau qu'il survolera ensuite doit déjà être prêt à le recevoir.
        let draggingFiles = isDraggingFiles
        windows.values.forEach { $0.setFileDragActive(draggingFiles) }

        // Un seul écran est testé, celui qui contient le curseur : avec plusieurs écrans
        // accolés, les zones sensibles du haut se touchent et tester toutes les zones déplierait
        // le panneau du mauvais écran.
        guard
            let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }),
            let displayID = screen.displayID,
            let window = windows[displayID]
        else {
            collapseActive()
            return
        }

        let inHotZone = NotchPanelGeometry.hotZone(on: screen).contains(location)
        // Le panneau reste déplié tant que le curseur est dessus : c'est ce qui permet d'aller
        // lire la carte sans que tout se referme en chemin.
        let overPanel = expandedDisplay == displayID && window.isExpanded && window.frame.contains(location)

        if isPinned {
            // Le panneau épinglé ne se replie qu'une fois le curseur venu dessus puis reparti —
            // sinon il disparaîtrait avant même que le pointeur l'ait atteint.
            if overPanel {
                hasVisitedPinnedPanel = true
                if isDraggingFiles { window.revealFileShelf() }
                updateRingHover(at: location, displayID: displayID)
            } else if hasVisitedPinnedPanel {
                isPinned = false
                collapseActive()
            }
            return
        }

        guard inHotZone || overPanel else {
            collapseActive()
            return
        }

        if expandedDisplay != displayID {
            collapseActive()
            expandedDisplay = displayID
        }
        window.apply(usageState: usageState, animated: false)
        window.setExpanded(true)
        startPolling()

        // Le panneau vient de s'ouvrir sous un glisser de fichiers : c'est le bac qu'on veut
        // voir, et c'est lui qui doit être là pour recevoir le dépôt. Le reste du dépôt est au
        // `FileTrayView` de l'onglet Tray — il n'y a pas d'autre cible de dépôt.
        if isDraggingFiles { window.revealFileShelf() }

        updateRingHover(at: location, displayID: displayID)
    }

    /// Un glisser de fichiers est-il en cours sous le curseur ? Le bouton gauche enfoncé ne
    /// suffit pas — déplacer une fenêtre lèverait le même drapeau —, donc on regarde aussi ce
    /// que porte le presse-papiers de glisser, que le système remplit pour tout le monde.
    private var isDraggingFiles: Bool {
        guard NSEvent.pressedMouseButtons & 1 != 0 else { return false }
        return NSPasteboard(name: .drag).canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
    }

    /// Confronte le curseur aux bagues : celle qu'il survole est mise en avant et reçoit la
    /// plaque d'accent. Seules les bagues branchées répondent, les autres n'ayant rien à montrer.
    private func updateRingHover(at location: NSPoint, displayID: CGDirectDisplayID) {
        guard let window = windows[displayID] else { return }

        let hovered = (0..<window.ringCount).first { index in
            SidePanelGeometry.ringSlots[index].isConnected
                && window.ringScreenRect(at: index)?.contains(location) ?? false
        }

        guard hovered != hoveredRingIndex else { return }
        hoveredRingIndex = hovered
        window.setHighlightedRing(hovered)
    }

    private func collapseActive() {
        isPinned = false
        hoveredRingIndex = nil
        guard let expandedDisplay else { return }
        windows[expandedDisplay]?.setExpanded(false)
        self.expandedDisplay = nil
        stopPolling()
    }

    // MARK: - Écrans

    private func rebuildWindows() {
        var connected: Set<CGDirectDisplayID> = []

        for screen in NSScreen.screens {
            guard let displayID = screen.displayID else { continue }
            connected.insert(displayID)

            let window: NotchPanelWindow
            if let existing = windows[displayID] {
                window = existing
            } else {
                window = NotchPanelWindow()
                // L'engrenage de la capsule ouvre les Préférences. Leur fenêtre active
                // l'app, donc le curseur a quitté le haut de l'écran et le suivi repliera le
                // panneau de lui-même.
                window.onOpenSettings = { SettingsWindowController.shared.show() }
                window.apply(usageState: usageState, animated: false)
                windows[displayID] = window
            }

            // Un écran déjà connu a pu changer de taille, de position ou de barre de menus : le
            // panneau est visible en permanence, donc tous sont recadrés, pas seulement l'actif.
            window.place(on: screen)
        }

        for (displayID, window) in windows where !connected.contains(displayID) {
            window.close()
            windows.removeValue(forKey: displayID)
            if expandedDisplay == displayID {
                expandedDisplay = nil
                stopPolling()
            }
        }
    }

    // MARK: - Rafraîchissement pendant le dépliage

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

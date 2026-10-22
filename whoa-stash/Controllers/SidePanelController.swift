import AppKit
import Combine

/// Gère un panneau par écran connecté : le révèle quand le curseur entre dans la zone sensible du
/// coin supérieur droit de l'écran survolé, le masque quand le curseur quitte à la fois cette zone
/// et le panneau. Reconstruit la liste des panneaux à chaque changement de configuration d'écrans
/// (branchement, débranchement, résolution, réagencement).
@MainActor
final class SidePanelController {

    private let mouseMonitor = GlobalMouseMonitor()

    /// Indexé par `CGDirectDisplayID` et non par position dans `NSScreen.screens`, qui change dès
    /// qu'un écran est branché ou débranché.
    private var windows: [CGDirectDisplayID: SidePanelWindow] = [:]
    private var activeDisplay: CGDirectDisplayID?

    private var screenObserver: NSObjectProtocol?
    private var appearanceCancellable: AnyCancellable?
    private var pollTimer: Timer?

    /// Les moniteurs d'événements ne se déclenchent qu'au mouvement : si le curseur est téléporté,
    /// ou qu'il quitte la zone pendant un changement de Space, plus aucun événement n'arrive et le
    /// panneau resterait ouvert. Ce rafraîchissement ne tourne que pendant qu'un panneau est visible.
    private let pollInterval: TimeInterval = 0.25

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

        appearanceCancellable = SettingsStorage.shared.$settings
            .map(\.general.appearanceMode)
            .removeDuplicates()
            .sink { [weak self] mode in
                self?.apply(appearanceMode: mode)
            }
    }

    private func apply(appearanceMode: AppearanceMode) {
        windows.values.forEach { $0.apply(appearanceMode: appearanceMode) }
    }

    // MARK: - Suivi du curseur

    private func handleCursor(at location: NSPoint) {
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

        guard inHotZone || overPanel else {
            hideActive()
            return
        }

        if activeDisplay != displayID {
            hideActive()
            activeDisplay = displayID
        }
        window.reveal(in: SidePanelGeometry.panelFrame(on: screen))
        startPolling()
    }

    private func hideActive() {
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
                window = SidePanelWindow()
                window.apply(appearanceMode: SettingsStorage.shared.settings.general.appearanceMode)
                windows[displayID] = window
            }

            // Un écran déjà connu a pu changer de taille ou de position ; seul le panneau visible
            // a besoin d'être recadré tout de suite, les autres le seront à leur prochain survol.
            if activeDisplay == displayID {
                window.setFrame(SidePanelGeometry.panelFrame(on: screen))
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

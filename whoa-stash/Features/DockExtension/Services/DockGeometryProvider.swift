import AppKit
import OSLog
import QuartzCore
@preconcurrency import ApplicationServices

/// Suit la position et la visibilité du vrai Dock via l'Accessibility API. Les notifications
/// AX (`kAXMovedNotification`/`kAXResizedNotification`) sont enregistrées en best-effort mais
/// ne sont *pas* fiables pour détecter le glissement du Dock en mode masquage automatique :
/// sur les versions récentes de macOS, le Dock n'expose plus de véritable `AXWindow` — seulement
/// une `AXList` qui ne supporte pas ces notifications (`AXObserverAddNotification` retourne
/// `kAXErrorNotificationUnsupported`/-25207, vérifié en pratique). On complète donc avec un
/// polling de la position/taille (2 lectures AX par tick) : c'est la seule méthode qui détecte
/// de façon fiable l'apparition/disparition du Dock. Sa cadence est adaptative — basse
/// fréquence au repos, cadence d'animation seulement le temps de suivre un mouvement
/// réellement détecté (voir `PollRate`).
@MainActor
final class DockGeometryProvider {

    var onChange: ((DockGeometry?) -> Void)?

    private var observer: AXObserver?
    private var dockAppElement: AXUIElement?
    private var dockWindowElement: AXUIElement?
    private var dockPID: pid_t?
    private var isObserving = false

    private var activationObserver: NSObjectProtocol?
    private var prefsObserver: NSObjectProtocol?

    /// Cadence du polling AX. Le Dock ne bouge que pendant ses animations de glissement : le
    /// reste du temps, l'interroger 60 fois par seconde revient à payer 120 allers-retours IPC
    /// synchrones par seconde sur le thread principal pour apprendre que rien n'a changé. On
    /// surveille donc à basse fréquence et on ne monte à la cadence d'animation que le temps de
    /// suivre un mouvement détecté.
    private enum PollRate {
        /// Veille : repère le début d'un glissement en ~83 ms au pire — imperceptible devant
        /// l'animation du Dock elle-même — pour 1/5 des lectures AX de l'ancienne cadence fixe.
        case idle
        /// Suivi d'un mouvement en cours : une lecture par frame, comme avant.
        case active

        var interval: TimeInterval {
            switch self {
            case .idle: return 1.0 / 12.0
            case .active: return 1.0 / 60.0
            }
        }
    }

    private var pollTimer: Timer?
    private var lastPolledFrame: CGRect?
    private var pollRate: PollRate = .idle
    private var lastPolledChange: CFTimeInterval = 0

    /// Durée sans aucun changement de frame au bout de laquelle on repasse en veille. Plus longue
    /// que l'animation de glissement du Dock, pour ne pas redescendre en plein mouvement.
    private let activeLingerDuration: TimeInterval = 0.5

    private let dockDefaults = UserDefaults(suiteName: "com.apple.dock")

    /// En dessous de cette hauteur (ou si le bas du Dock dépasse le bas de l'écran de plus de
    /// cette marge), on considère le Dock masqué plutôt que de deviner un délai d'animation.
    private let hiddenEdgeThreshold: CGFloat = 4

    func start() {
        Log.dockGeometry.debug("start()")

        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Log.dockGeometry.debug("didBecomeActiveNotification → nouvelle tentative de setUpIfNeeded()")
            Task { @MainActor in self?.setUpIfNeeded() }
        }

        prefsObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.dock.prefchanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Log.dockGeometry.debug("com.apple.dock.prefchanged reçu")
            Task { @MainActor in self?.refreshGeometry() }
        }

        setUpIfNeeded()
    }

    func stop() {
        if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) }
        if let prefsObserver { DistributedNotificationCenter.default().removeObserver(prefsObserver) }
        activationObserver = nil
        prefsObserver = nil
        stopPolling()
        teardownObserver()
    }

    // MARK: - Polling (détection fiable de l'apparition/disparition du Dock)

    private func startPolling() {
        guard pollTimer == nil else { return }
        Log.dockGeometry.debug("startPolling() — démarrage en veille (\(PollRate.idle.interval, privacy: .public)s)")
        pollRate = .idle
        lastPolledChange = CACurrentMediaTime()
        scheduleTimer(for: pollRate)
    }

    private func stopPolling() {
        guard pollTimer != nil else { return }
        Log.dockGeometry.debug("stopPolling()")
        pollTimer?.invalidate()
        pollTimer = nil
        lastPolledFrame = nil
        pollRate = .idle
    }

    /// `Timer` ne permet pas de changer son intervalle après coup : changer de cadence revient
    /// donc à remplacer le timer.
    private func scheduleTimer(for rate: PollRate) {
        pollTimer?.invalidate()
        // Le timer est ajouté à `RunLoop.main`, son bloc s'exécute donc toujours sur le thread
        // principal : `assumeIsolated` suffit, là où un `Task { @MainActor in }` allouerait une
        // tâche et un saut d'exécuteur à chaque tick.
        let timer = Timer(timeInterval: rate.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollTick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func setPollRate(_ rate: PollRate) {
        guard pollRate != rate else { return }
        Log.dockGeometry.debug("cadence de polling → \(String(describing: rate), privacy: .public) (\(rate.interval, privacy: .public)s)")
        pollRate = rate
        scheduleTimer(for: rate)
    }

    /// Ne fait que 2 lectures AX bon marché (position/taille) et compare au tick précédent. Le
    /// traitement complet (`refreshGeometry`, avec toute sa journalisation) n'est déclenché que
    /// lorsque le frame a réellement changé — donc uniquement pendant l'animation de glissement
    /// du Dock, pas en continu pendant que l'app tourne.
    private func pollTick() {
        guard let window = dockWindowElement, let axFrame = frame(of: window) else {
            guard lastPolledFrame != nil else {
                relaxPollRateIfSettled()
                return
            }
            Log.dockGeometry.debug("pollTick() — fenêtre du Dock devenue illisible → refreshGeometry()")
            lastPolledFrame = nil
            noteFrameChanged()
            refreshGeometry()
            return
        }
        guard axFrame != lastPolledFrame else {
            relaxPollRateIfSettled()
            return
        }
        lastPolledFrame = axFrame
        noteFrameChanged()
        refreshGeometry()
    }

    /// Le Dock vient de bouger : on suit à la cadence d'animation et on repousse le retour
    /// en veille.
    private func noteFrameChanged() {
        lastPolledChange = CACurrentMediaTime()
        setPollRate(.active)
    }

    /// Rien n'a changé à ce tick : on retombe en veille dès que le Dock est immobile depuis
    /// `activeLingerDuration`.
    private func relaxPollRateIfSettled() {
        guard pollRate == .active,
              CACurrentMediaTime() - lastPolledChange >= activeLingerDuration else { return }
        setPollRate(.idle)
    }

    // MARK: - Configuration AX

    private func setUpIfNeeded() {
        Log.dockGeometry.debug("setUpIfNeeded() — isObserving=\(self.isObserving, privacy: .public)")
        guard !isObserving else {
            Log.dockGeometry.debug("déjà observé, on ne refait rien")
            return
        }

        let trusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        Log.dockGeometry.debug("AXIsProcessTrustedWithOptions → \(trusted, privacy: .public)")
        guard trusted else {
            Log.dockGeometry.error("permission Accessibilité NON accordée — extension inactive jusqu'à l'octroi (Réglages Système > Confidentialité et sécurité > Accessibilité)")
            onChange?(nil)
            return
        }

        guard let dockApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) else {
            Log.dockGeometry.error("process Dock introuvable parmi runningApplications")
            return
        }

        let pid = dockApp.processIdentifier
        Log.dockGeometry.debug("process Dock trouvé, pid=\(pid, privacy: .public)")
        dockPID = pid
        let appElement = AXUIElementCreateApplication(pid)
        dockAppElement = appElement

        let callback: AXObserverCallback = { _, _, notification, refcon in
            guard let refcon else { return }
            Log.dockGeometry.debug("notification AX reçue: \(notification as String, privacy: .public)")
            Task { @MainActor in
                Unmanaged<DockGeometryProvider>.fromOpaque(refcon).takeUnretainedValue().refreshGeometry()
            }
        }

        var observerRef: AXObserver?
        let createResult = AXObserverCreate(pid, callback, &observerRef)
        guard createResult == .success, let observerRef else {
            Log.dockGeometry.error("impossible de créer l'AXObserver pour le Dock (erreur \(createResult.rawValue, privacy: .public))")
            return
        }

        observer = observerRef
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        for notification in [kAXWindowCreatedNotification, kAXUIElementDestroyedNotification] {
            let result = AXObserverAddNotification(observerRef, appElement, notification as CFString, selfPtr)
            Log.dockGeometry.debug("AXObserverAddNotification(app, \(notification, privacy: .public)) → \(result.rawValue, privacy: .public)")
        }

        dockWindowElement = findDockWindow(in: appElement)
        Log.dockGeometry.debug("fenêtre du Dock trouvée à l'init ? \(self.dockWindowElement != nil, privacy: .public)")
        attachWindowNotifications()

        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observerRef), .defaultMode)
        isObserving = true
        startPolling()

        Log.dockGeometry.info("suivi AX du Dock activé")
        refreshGeometry()
    }

    private func teardownObserver() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        dockAppElement = nil
        dockWindowElement = nil
        dockPID = nil
        isObserving = false
        stopPolling()
    }

    private func attachWindowNotifications() {
        guard let observer, let window = dockWindowElement else {
            Log.dockGeometry.debug("attachWindowNotifications() annulé (observer ou window nil)")
            return
        }
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        for notification in [kAXMovedNotification, kAXResizedNotification, kAXUIElementDestroyedNotification] {
            let result = AXObserverAddNotification(observer, window, notification as CFString, selfPtr)
            Log.dockGeometry.debug("AXObserverAddNotification(window, \(notification, privacy: .public)) → \(result.rawValue, privacy: .public)")
        }
    }

    private func findDockWindow(in appElement: AXUIElement) -> AXUIElement? {
        var windowsRef: CFTypeRef?
        let windowsResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        Log.dockGeometry.debug("findDockWindow — kAXWindowsAttribute → result=\(windowsResult.rawValue, privacy: .public), count=\((windowsRef as? [AXUIElement])?.count ?? -1, privacy: .public)")
        if windowsResult == .success, let windows = windowsRef as? [AXUIElement], let first = windows.first {
            return first
        }

        var childrenRef: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &childrenRef)
        guard let children = childrenRef as? [AXUIElement] else {
            Log.dockGeometry.debug("findDockWindow — kAXChildrenAttribute → result=\(childrenResult.rawValue, privacy: .public), aucun enfant exploitable")
            return nil
        }
        Log.dockGeometry.debug("findDockWindow — kAXChildrenAttribute → \(children.count, privacy: .public) enfant(s), recherche du rôle AXWindow")

        for child in children {
            Log.dockGeometry.debug("findDockWindow — enfant avec rôle \(self.role(of: child) ?? "?", privacy: .public)")
        }

        if let windowMatch = children.first(where: { role(of: $0) == (kAXWindowRole as String) }) {
            Log.dockGeometry.debug("findDockWindow — match par rôle AXWindow")
            return windowMatch
        }

        // Sur les versions récentes de macOS, le Dock n'expose plus de véritable AXWindow : son
        // seul enfant utile est une AXList qui porte directement la position/taille à l'écran.
        // On retombe sur le premier enfant dont la géométrie est lisible plutôt que d'exiger le
        // rôle AXWindow, sans quoi `dockWindowElement` reste nil et rien ne s'affiche jamais.
        let geometryMatch = children.first { frame(of: $0) != nil }
        Log.dockGeometry.debug("findDockWindow — pas d'enfant AXWindow, repli sur géométrie exploitable, trouvé ? \(geometryMatch != nil, privacy: .public) (rôle=\(geometryMatch.flatMap(self.role) ?? "?", privacy: .public))")
        return geometryMatch
    }

    private func role(of element: AXUIElement) -> String? {
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success else { return nil }
        return roleRef as? String
    }

    private func elementStillValid(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) != .invalidUIElement
    }

    // MARK: - Géométrie

    private func refreshGeometry() {
        Log.dockGeometry.debug("refreshGeometry()")

        guard isBottomOriented else {
            Log.dockGeometry.info("Dock non orienté en bas (orientation=\(self.dockDefaults?.string(forKey: "orientation") ?? "?", privacy: .public)), extension non gérée dans cette configuration → onChange(nil)")
            onChange?(nil)
            return
        }

        if let window = dockWindowElement, !elementStillValid(window) {
            Log.dockGeometry.debug("référence de fenêtre invalide, recherche d'une nouvelle fenêtre Dock")
            dockWindowElement = dockAppElement.flatMap(findDockWindow)
            attachWindowNotifications()
        }

        guard let window = dockWindowElement else {
            Log.dockGeometry.debug("aucune fenêtre Dock disponible → onChange(nil)")
            onChange?(nil)
            return
        }

        guard let axFrame = frame(of: window) else {
            Log.dockGeometry.debug("impossible de lire position/taille de la fenêtre Dock → onChange(nil)")
            onChange?(nil)
            return
        }

        Log.dockGeometry.debug("frame AX brut = \(String(describing: axFrame), privacy: .public)")
        let appKitFrame = convertToAppKitCoordinates(axFrame)
        Log.dockGeometry.debug("frame converti (AppKit) = \(String(describing: appKitFrame), privacy: .public)")

        guard let screen = screen(forAppKitFrame: appKitFrame) else {
            Log.dockGeometry.debug("aucun écran ne correspond au frame → onChange(nil)")
            onChange?(nil)
            return
        }
        Log.dockGeometry.debug("écran correspondant = \(String(describing: screen.frame), privacy: .public)")

        guard !isHidden(appKitFrame, on: screen) else {
            Log.dockGeometry.debug("Dock considéré MASQUÉ (hauteur=\(appKitFrame.height, privacy: .public), maxY=\(appKitFrame.maxY, privacy: .public), screen.minY=\(screen.frame.minY, privacy: .public)) → onChange(nil)")
            onChange?(nil)
            return
        }

        let tileSize = dockDefaults?.double(forKey: "tilesize") ?? 64
        Log.dockGeometry.debug("Dock VISIBLE — frame=\(String(describing: appKitFrame), privacy: .public), tileSize=\(tileSize, privacy: .public) → onChange(geometry)")
        onChange?(DockGeometry(frame: appKitFrame, screen: screen, tileSize: CGFloat(tileSize)))
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let positionRef, let sizeRef else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else { return nil }

        return CGRect(origin: point, size: size)
    }

    /// L'Accessibility API renvoie des coordonnées Quartz (origine en haut à gauche de l'écran
    /// principal) ; AppKit attend une origine en bas à gauche — conversion classique via la
    /// hauteur de l'écran principal (`NSScreen.screens[0]`), quel que soit l'écran final concerné.
    private func convertToAppKitCoordinates(_ axFrame: CGRect) -> NSRect {
        guard let primary = NSScreen.screens.first else { return axFrame }
        let flippedY = primary.frame.height - axFrame.origin.y - axFrame.height
        return NSRect(x: axFrame.origin.x, y: flippedY, width: axFrame.width, height: axFrame.height)
    }

    private func screen(forAppKitFrame frame: NSRect) -> NSScreen? {
        NSScreen.screens.first { $0.frame.minX <= frame.midX && frame.midX <= $0.frame.maxX } ?? NSScreen.main
    }

    private func isHidden(_ frame: NSRect, on screen: NSScreen) -> Bool {
        frame.height <= hiddenEdgeThreshold || frame.maxY <= screen.frame.minY + hiddenEdgeThreshold
    }

    private var isBottomOriented: Bool {
        (dockDefaults?.string(forKey: "orientation") ?? "bottom") == "bottom"
    }
}

import AppKit
@preconcurrency import ApplicationServices

/// Suit la position et la visibilité du vrai Dock via l'Accessibility API. Les notifications
/// AX (`kAXMovedNotification`/`kAXResizedNotification`) sont enregistrées en best-effort mais
/// ne sont *pas* fiables pour détecter le glissement du Dock en mode masquage automatique :
/// sur les versions récentes de macOS, le Dock n'expose plus de véritable `AXWindow` — seulement
/// une `AXList` qui ne supporte pas ces notifications (`AXObserverAddNotification` retourne
/// `kAXErrorNotificationUnsupported`/-25207, vérifié en pratique). On complète donc avec un
/// polling léger de la position/taille (2 lectures AX par tick) pendant que l'app tourne : c'est
/// la seule méthode qui détecte de façon fiable l'apparition/disparition du Dock.
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

    private var pollTimer: Timer?
    private var lastPolledFrame: CGRect?
    private let pollInterval: TimeInterval = 1.0 / 60.0

    private let dockDefaults = UserDefaults(suiteName: "com.apple.dock")

    /// En dessous de cette hauteur (ou si le bas du Dock dépasse le bas de l'écran de plus de
    /// cette marge), on considère le Dock masqué plutôt que de deviner un délai d'animation.
    private let hiddenEdgeThreshold: CGFloat = 4

    func start() {
        print("[DockExt][Geometry] start()")

        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[DockExt][Geometry] didBecomeActiveNotification → nouvelle tentative de setUpIfNeeded()")
            Task { @MainActor in self?.setUpIfNeeded() }
        }

        prefsObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.dock.prefchanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[DockExt][Geometry] com.apple.dock.prefchanged reçu")
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
        print("[DockExt][Geometry] startPolling() — intervalle=\(pollInterval)s")
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollTick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func stopPolling() {
        guard pollTimer != nil else { return }
        print("[DockExt][Geometry] stopPolling()")
        pollTimer?.invalidate()
        pollTimer = nil
        lastPolledFrame = nil
    }

    /// Tick à haute fréquence : ne fait que 2 lectures AX bon marché (position/taille) et compare
    /// au tick précédent. Le traitement complet (`refreshGeometry`, avec toute sa journalisation)
    /// n'est déclenché que lorsque le frame a réellement changé — donc typiquement uniquement
    /// pendant l'animation de glissement du Dock, pas en continu pendant que l'app tourne.
    private func pollTick() {
        guard let window = dockWindowElement, let axFrame = frame(of: window) else {
            guard lastPolledFrame != nil else { return }
            print("[DockExt][Geometry] pollTick(): fenêtre du Dock devenue illisible → refreshGeometry()")
            lastPolledFrame = nil
            refreshGeometry()
            return
        }
        guard axFrame != lastPolledFrame else { return }
        lastPolledFrame = axFrame
        refreshGeometry()
    }

    // MARK: - Configuration AX

    private func setUpIfNeeded() {
        print("[DockExt][Geometry] setUpIfNeeded() — isObserving=\(isObserving)")
        guard !isObserving else {
            print("[DockExt][Geometry] déjà observé, on ne refait rien")
            return
        }

        let trusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        print("[DockExt][Geometry] AXIsProcessTrustedWithOptions → \(trusted)")
        guard trusted else {
            print("[DockExt][Geometry] ⛔️ permission Accessibilité NON accordée — extension inactive jusqu'à l'octroi (vérifier Réglages Système > Confidentialité et sécurité > Accessibilité).")
            onChange?(nil)
            return
        }

        guard let dockApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dock" }) else {
            print("[DockExt][Geometry] ⛔️ process Dock introuvable parmi runningApplications.")
            return
        }

        let pid = dockApp.processIdentifier
        print("[DockExt][Geometry] process Dock trouvé, pid=\(pid)")
        dockPID = pid
        let appElement = AXUIElementCreateApplication(pid)
        dockAppElement = appElement

        let callback: AXObserverCallback = { _, _, notification, refcon in
            guard let refcon else { return }
            print("[DockExt][Geometry] notification AX reçue: \(notification as String)")
            Task { @MainActor in
                Unmanaged<DockGeometryProvider>.fromOpaque(refcon).takeUnretainedValue().refreshGeometry()
            }
        }

        var observerRef: AXObserver?
        let createResult = AXObserverCreate(pid, callback, &observerRef)
        guard createResult == .success, let observerRef else {
            print("[DockExt][Geometry] ⛔️ impossible de créer l'AXObserver pour le Dock (erreur \(createResult.rawValue)).")
            return
        }

        observer = observerRef
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        for notification in [kAXWindowCreatedNotification, kAXUIElementDestroyedNotification] {
            let result = AXObserverAddNotification(observerRef, appElement, notification as CFString, selfPtr)
            print("[DockExt][Geometry] AXObserverAddNotification(app, \(notification)) → \(result.rawValue)")
        }

        dockWindowElement = findDockWindow(in: appElement)
        print("[DockExt][Geometry] fenêtre du Dock trouvée à l'init ? \(dockWindowElement != nil)")
        attachWindowNotifications()

        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observerRef), .defaultMode)
        isObserving = true
        startPolling()

        print("[DockExt][Geometry] ✅ suivi AX du Dock activé.")
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
            print("[DockExt][Geometry] attachWindowNotifications() annulé (observer ou window nil)")
            return
        }
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        for notification in [kAXMovedNotification, kAXResizedNotification, kAXUIElementDestroyedNotification] {
            let result = AXObserverAddNotification(observer, window, notification as CFString, selfPtr)
            print("[DockExt][Geometry] AXObserverAddNotification(window, \(notification)) → \(result.rawValue)")
        }
    }

    private func findDockWindow(in appElement: AXUIElement) -> AXUIElement? {
        var windowsRef: CFTypeRef?
        let windowsResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        print("[DockExt][Geometry] findDockWindow: kAXWindowsAttribute → result=\(windowsResult.rawValue), count=\((windowsRef as? [AXUIElement])?.count ?? -1)")
        if windowsResult == .success, let windows = windowsRef as? [AXUIElement], let first = windows.first {
            return first
        }

        var childrenRef: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(appElement, kAXChildrenAttribute as CFString, &childrenRef)
        guard let children = childrenRef as? [AXUIElement] else {
            print("[DockExt][Geometry] findDockWindow: kAXChildrenAttribute → result=\(childrenResult.rawValue), aucun enfant exploitable")
            return nil
        }
        print("[DockExt][Geometry] findDockWindow: kAXChildrenAttribute → \(children.count) enfant(s), recherche du rôle AXWindow")

        for child in children {
            print("[DockExt][Geometry] findDockWindow: enfant avec rôle \(role(of: child) ?? "?")")
        }

        if let windowMatch = children.first(where: { role(of: $0) == (kAXWindowRole as String) }) {
            print("[DockExt][Geometry] findDockWindow: match par rôle AXWindow")
            return windowMatch
        }

        // Sur les versions récentes de macOS, le Dock n'expose plus de véritable AXWindow : son
        // seul enfant utile est une AXList qui porte directement la position/taille à l'écran.
        // On retombe sur le premier enfant dont la géométrie est lisible plutôt que d'exiger le
        // rôle AXWindow, sans quoi `dockWindowElement` reste nil et rien ne s'affiche jamais.
        let geometryMatch = children.first { frame(of: $0) != nil }
        print("[DockExt][Geometry] findDockWindow: pas d'enfant AXWindow — repli sur géométrie exploitable, trouvé ? \(geometryMatch != nil) (rôle=\(geometryMatch.flatMap(role) ?? "?"))")
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
        print("[DockExt][Geometry] refreshGeometry()")

        guard isBottomOriented else {
            print("[DockExt][Geometry] ⛔️ Dock non orienté en bas (orientation=\(dockDefaults?.string(forKey: "orientation") ?? "?")) → onChange(nil)")
            onChange?(nil)
            return
        }

        if let window = dockWindowElement, !elementStillValid(window) {
            print("[DockExt][Geometry] référence de fenêtre invalide, recherche d'une nouvelle fenêtre Dock")
            dockWindowElement = dockAppElement.flatMap(findDockWindow)
            attachWindowNotifications()
        }

        guard let window = dockWindowElement else {
            print("[DockExt][Geometry] ⛔️ aucune fenêtre Dock disponible → onChange(nil)")
            onChange?(nil)
            return
        }

        guard let axFrame = frame(of: window) else {
            print("[DockExt][Geometry] ⛔️ impossible de lire position/taille de la fenêtre Dock → onChange(nil)")
            onChange?(nil)
            return
        }

        print("[DockExt][Geometry] frame AX brut = \(axFrame)")
        let appKitFrame = convertToAppKitCoordinates(axFrame)
        print("[DockExt][Geometry] frame converti (AppKit) = \(appKitFrame)")

        guard let screen = screen(forAppKitFrame: appKitFrame) else {
            print("[DockExt][Geometry] ⛔️ aucun écran ne correspond au frame → onChange(nil)")
            onChange?(nil)
            return
        }
        print("[DockExt][Geometry] écran correspondant = \(screen.frame)")

        guard !isHidden(appKitFrame, on: screen) else {
            print("[DockExt][Geometry] Dock considéré MASQUÉ (hauteur=\(appKitFrame.height), maxY=\(appKitFrame.maxY), screen.minY=\(screen.frame.minY)) → onChange(nil)")
            onChange?(nil)
            return
        }

        let tileSize = dockDefaults?.double(forKey: "tilesize") ?? 64
        print("[DockExt][Geometry] ✅ Dock VISIBLE — frame=\(appKitFrame), tileSize=\(tileSize) → onChange(geometry)")
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

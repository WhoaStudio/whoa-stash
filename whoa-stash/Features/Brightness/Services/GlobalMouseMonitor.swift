import AppKit

/// Émet la position globale du curseur à chaque déplacement, en combinant un moniteur
/// global (autres apps) et local (notre app) — aucune permission d'accessibilité requise.
@MainActor
final class GlobalMouseMonitor {

    var onMove: ((NSPoint) -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start() {
        stop()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.onMove?(NSEvent.mouseLocation)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.onMove?(NSEvent.mouseLocation)
            return event
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }
}

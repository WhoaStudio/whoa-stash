import AppKit

/// Émet la position globale du curseur à chaque déplacement, en combinant un moniteur
/// global (autres apps) et local (notre app) — aucune permission d'accessibilité requise.
@MainActor
final class GlobalMouseMonitor {

    var onMove: ((NSPoint) -> Void)?

    /// Suivre aussi le curseur **bouton gauche enfoncé**. Un glisser — de fichiers depuis le
    /// Finder, par exemple — n'émet pas de `.mouseMoved` : sans cela, un panneau qui se déplie
    /// au survol resterait replié tout au long du glisser, et n'aurait jamais l'occasion de
    /// recevoir le dépôt. Hors de ce cas, les surcoûts d'un événement par image de glisser ne
    /// servent à rien, d'où le défaut.
    private let tracksDrags: Bool

    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(tracksDrags: Bool = false) {
        self.tracksDrags = tracksDrags
    }

    func start() {
        stop()

        let mask: NSEvent.EventTypeMask = tracksDrags ? [.mouseMoved, .leftMouseDragged] : [.mouseMoved]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            self?.onMove?(NSEvent.mouseLocation)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
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

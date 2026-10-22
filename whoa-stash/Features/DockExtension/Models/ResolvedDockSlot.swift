import AppKit

/// Un slot configuré, résolu en icône/nom réels — construit uniquement pour les emplacements
/// non vides dont l'app existe encore sur le disque.
struct ResolvedDockSlot {
    let index: Int
    let bundleURL: URL
    let icon: NSImage
    let name: String
}

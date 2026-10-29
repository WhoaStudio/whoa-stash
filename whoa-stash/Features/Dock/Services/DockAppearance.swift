import Foundation

/// Réglages du Dock macOS que le dock personnalisé reprend par défaut : taille des icônes,
/// agrandissement au survol, masquage auto, rebond au lancement. Lus dans `com.apple.dock`.
struct DockAppearance: Equatable, Sendable {
    var iconSize: CGFloat = 48
    var magnification = false
    var magnifiedSize: CGFloat = 128
    var autohide = false
    /// Délai avant l'apparition au contact du bord, en secondes.
    var revealDelay: Double = 0.5
    var bounceOnLaunch = true

    /// Quand l'app a masqué le Dock système, `autohide` et `autohide-delay` valent *nos* valeurs
    /// (masquage + 1000 s) : le dock personnalisé reprend alors celles de la sauvegarde, qui sont
    /// les vraies préférences de l'utilisateur.
    @MainActor
    static func read(from defaults: DockDefaultsAccessing, saved: SavedSystemDock?) -> DockAppearance {
        var result = DockAppearance()
        if let size = defaults.double("tilesize"), size > 0 { result.iconSize = CGFloat(size) }
        result.magnification = defaults.bool("magnification") ?? false
        if let large = defaults.double("largesize"), large > 0 { result.magnifiedSize = CGFloat(large) }
        result.magnifiedSize = max(result.magnifiedSize, result.iconSize)
        result.bounceOnLaunch = defaults.bool("launchanim") ?? true
        if let saved {
            result.autohide = saved.autohide ?? false
            if let delay = saved.autohideDelay { result.revealDelay = delay }
        } else {
            result.autohide = defaults.bool("autohide") ?? false
            if let delay = defaults.double("autohide-delay") { result.revealDelay = delay }
        }
        return result
    }
}

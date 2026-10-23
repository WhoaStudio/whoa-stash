import AppKit

/// Une catégorie de la sidebar des Préférences — ordre d'affichage = ordre des cas.
enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case brightness
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .brightness: return "Brightness"
        case .about: return "About"
        }
    }

    var symbolName: String {
        switch self {
        case .general: return "gearshape"
        case .brightness: return "sun.max"
        case .about: return "info.circle"
        }
    }

    /// Couleur de la tuile derrière l'icône dans la sidebar — une teinte par catégorie, comme
    /// dans les Réglages Système, pour distinguer les entrées au premier coup d'œil.
    var tintColor: NSColor {
        switch self {
        case .general: return .systemBlue
        case .brightness: return .systemOrange
        case .about: return .systemGreen
        }
    }
}

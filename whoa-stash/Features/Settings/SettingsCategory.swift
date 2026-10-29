import AppKit

/// Une catégorie de la sidebar des Préférences — ordre d'affichage = ordre des cas.
enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case brightness
    case knock
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .brightness: return "Brightness"
        case .knock: return "Knock"
        case .about: return "About"
        }
    }

    var symbolName: String {
        switch self {
        case .general: return "gearshape"
        case .brightness: return "sun.max"
        case .knock: return "hand.tap"
        case .about: return "info.circle"
        }
    }
}

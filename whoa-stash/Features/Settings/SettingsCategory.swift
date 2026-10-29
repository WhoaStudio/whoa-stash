import AppKit

/// Une catégorie de la sidebar des Préférences — ordre d'affichage = ordre des cas.
enum SettingsCategory: String, CaseIterable, Identifiable {
    case general
    case brightness
    case knock
    case radialMenu
    case dock
    case workspaces
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .brightness: return "Brightness"
        case .knock: return "Knock"
        case .radialMenu: return "Radial Menu"
        case .dock: return "Dock"
        case .workspaces: return "Workspaces"
        case .about: return "About"
        }
    }

    var symbolName: String {
        switch self {
        case .general: return "gearshape"
        case .brightness: return "sun.max"
        case .knock: return "hand.tap"
        case .radialMenu: return "circle.dotted"
        case .dock: return "dock.rectangle"
        case .workspaces: return "square.grid.2x2"
        case .about: return "info.circle"
        }
    }
}

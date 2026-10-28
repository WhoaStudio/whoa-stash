import Foundation

/// Les onglets de la barre haute du panneau, dans l'ordre où ils s'y présentent.
///
/// `Global` porte la bande horizontale de la semaine ; `Calendar` porte l'agenda et la grille
/// mensuelle ; `Tray` recueille les fichiers qu'on y dépose ; `Mirror` montre la caméra dans un
/// cercle ; `AI` porte l'utilisation des agents.
enum NotchTab: Int, CaseIterable {
    case global
    case calendar
    case tray
    case mirror
    case ai

    var title: String {
        switch self {
        case .global: "Global"
        case .calendar: "Calendar"
        case .tray: "Tray"
        case .mirror: "Mirror"
        case .ai: "AI"
        }
    }

    /// Glyphe SF Symbols de l'onglet. Tous existent depuis longtemps dans le système, donc pas
    /// de repli à prévoir côté vue.
    var symbolName: String {
        switch self {
        case .global: "globe"
        case .calendar: "calendar"
        case .tray: "tray"
        case .mirror: "camera"
        case .ai: "sparkles"
        }
    }
}

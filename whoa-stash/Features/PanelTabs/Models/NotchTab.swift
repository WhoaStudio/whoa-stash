import Foundation

/// Les onglets de la barre haute du panneau, dans l'ordre où ils s'y présentent.
///
/// `Global` porte la bande horizontale de la semaine ; `Calendar` porte l'agenda et la grille
/// mensuelle ; `Tray` recueille les fichiers qu'on y dépose ; `Clipboard` garde l'historique des copies ; `Mirror` montre la caméra dans un
/// cercle ; `AI` porte l'utilisation des agents.
enum NotchTab: Int, CaseIterable {
    case global
    case calendar
    case tray
    case clipboard
    case mirror
    case ai

    /// L'onglet voisin dans le sens donné, ou `nil` au bout de la rangée — on ne reboucle pas.
    func neighbor(_ direction: TabSwipeTracker.Direction) -> NotchTab? {
        NotchTab(rawValue: rawValue + (direction == .next ? 1 : -1))
    }

    var title: String {
        switch self {
        case .global: "Global"
        case .calendar: "Calendar"
        case .tray: "Tray"
        case .clipboard: "Clipboard"
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
        case .clipboard: "doc.on.clipboard"
        case .mirror: "camera"
        case .ai: "sparkles"
        }
    }
}

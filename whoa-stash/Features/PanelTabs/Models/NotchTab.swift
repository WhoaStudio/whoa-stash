import Foundation

/// Les onglets de la barre haute du panneau, dans l'ordre où ils s'y présentent.
///
/// `Global` porte le contenu historique du panneau — la semaine et les bagues d'utilisation ;
/// `Tray` recueille les fichiers qu'on y dépose ; `AI` est réservé et n'affiche encore qu'un
/// écriteau.
enum NotchTab: Int, CaseIterable {
    case global
    case tray
    case ai

    var title: String {
        switch self {
        case .global: "Global"
        case .tray: "Tray"
        case .ai: "AI"
        }
    }

    /// Glyphe SF Symbols de l'onglet. Tous existent depuis longtemps dans le système, donc pas
    /// de repli à prévoir côté vue.
    var symbolName: String {
        switch self {
        case .global: "globe"
        case .tray: "tray"
        case .ai: "sparkles"
        }
    }
}

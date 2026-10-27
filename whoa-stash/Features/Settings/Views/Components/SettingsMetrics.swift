import AppKit

/// Constantes visuelles partagées par toutes les vues de Préférences — un seul endroit à
/// ajuster pour garder la fenêtre cohérente.
enum SettingsMetrics {
    static let sidebarWidth: CGFloat = 200
    /// Hauteur taillée sur l'écran le plus dense — « General », qui porte cinq cartes et dix
    /// lignes. Le scroll view de `SettingsSectionViewController` reste le filet de sécurité,
    /// mais aucun écran ne doit avoir besoin de défiler pour être lu en entier.
    static let windowSize = NSSize(width: 760, height: 700)

    static let contentInset: CGFloat = 28
    static let cardSpacing: CGFloat = 20
    static let cardCornerRadius: CGFloat = 14
    static let cardHeaderSpacing: CGFloat = 8

    static let rowHorizontalPadding: CGFloat = 16
    static let rowMinHeight: CGFloat = 44
    static let rowControlWidth: CGFloat = 180

    static let sidebarItemHeight: CGFloat = 32
    static let sidebarItemSpacing: CGFloat = 4
    static let sidebarItemCornerRadius: CGFloat = 7
    static let sidebarPadding: CGFloat = 12

    static let sidebarIconTileSize: CGFloat = 22
    static let sidebarIconTileCornerRadius: CGFloat = 6

    /// Durée des micro-animations quand `enableAnimations` est actif.
    static let transitionDuration: TimeInterval = 0.18
}

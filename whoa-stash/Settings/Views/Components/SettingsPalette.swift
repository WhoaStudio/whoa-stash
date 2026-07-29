import AppKit

/// Constantes visuelles partagées par toutes les vues de Préférences — un seul endroit à
/// ajuster pour garder la fenêtre cohérente.
enum SettingsMetrics {
    static let sidebarWidth: CGFloat = 200
    static let windowSize = NSSize(width: 760, height: 560)

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

enum SettingsPalette {
    /// Fond léger et distinct du fond de fenêtre — matérialise chaque carte comme dans Klack.
    static let cardMaterial: NSVisualEffectView.Material = .contentBackground

    static let rowSeparator = NSColor.separatorColor.withAlphaComponent(0.5)

    /// Fond de la ligne sélectionnée dans la sidebar : un gris clair opaque, non teinté par la
    /// couleur d'accent — comme les Réglages Système, pas une simple teinte translucide (trop
    /// discrète pour se détacher du matériau `.sidebar` déjà clair).
    static let sidebarSelection = NSColor.controlBackgroundColor
}

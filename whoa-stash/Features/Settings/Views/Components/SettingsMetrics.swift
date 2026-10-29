import AppKit

/// Constantes visuelles partagées par toutes les vues de Préférences — un seul endroit à
/// ajuster pour garder la fenêtre cohérente.
enum SettingsMetrics {
    /// Hauteur taillée sur l'écran le plus dense — « General ». Le scroll view de
    /// `SettingsSectionViewController` reste le filet de sécurité.
    static let windowSize = NSSize(width: 900, height: 760)

    /// Zone de la barre de titre transparente, sous laquelle commence la barre d'onglets.
    static let titleBarHeight: CGFloat = 28

    static let tabBarHeight: CGFloat = 84
    static let tabItemSize = NSSize(width: 88, height: 62)
    static let tabItemSpacing: CGFloat = 6
    static let tabItemCornerRadius: CGFloat = 10

    static let contentWidth: CGFloat = 680
    static let contentTopInset: CGFloat = 28
    static let contentBottomInset: CGFloat = 28
    static let rowSpacing: CGFloat = 18

    static let labelColumnWidth: CGFloat = 190
    static let labelControlGap: CGFloat = 16
    /// Hauteur d'une ligne de contrôle simple : le libellé et les contrôles courts s'y centrent.
    static let firstLineHeight: CGFloat = 28
    static let captionSpacing: CGFloat = 6
    static let captionMaxWidth: CGFloat = 400

    static let sliderWidth: CGFloat = 180
    static let keyButtonSize = NSSize(width: 280, height: 34)
    static let bannerWidth: CGFloat = 360
    static let bannerCornerRadius: CGFloat = 14

    static let choiceSpacing: CGFloat = 10
    static let iconChoiceSize: CGFloat = 52
    static let thumbnailSize = NSSize(width: 84, height: 56)

    /// Durée des micro-animations quand `enableAnimations` est actif.
    static let transitionDuration: TimeInterval = 0.18
}

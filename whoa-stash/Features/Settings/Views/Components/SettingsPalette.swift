import AppKit

enum SettingsPalette {
    /// Fond léger et distinct du fond de fenêtre — matérialise chaque carte comme dans Klack.
    static let cardMaterial: NSVisualEffectView.Material = .contentBackground

    static let rowSeparator = NSColor.separatorColor.withAlphaComponent(0.5)

    /// Fond de la ligne sélectionnée dans la sidebar : un gris clair opaque, non teinté par la
    /// couleur d'accent — comme les Réglages Système, pas une simple teinte translucide (trop
    /// discrète pour se détacher du matériau `.sidebar` déjà clair).
    static let sidebarSelection = NSColor.controlBackgroundColor
}

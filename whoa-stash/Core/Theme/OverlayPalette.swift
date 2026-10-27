import AppKit

/// Jeu de couleurs et de matériaux résolu pour une apparence donnée (clair/sombre).
/// Le vert des graduations actives est volontairement identique dans les deux palettes —
/// seul l'environnement autour de lui doit s'adapter.
struct OverlayPalette {
    var activeTickColor: CGColor
    var inactiveTickColor: CGColor
    var glowOpacity: Float
    var glowRadius: CGFloat

    /// Matériau translucide et sa teinte. Plus personne ne s'en sert depuis que le widget de
    /// luminosité est passé au fond plein : gardés pour un éventuel retour au translucide.
    var backgroundMaterial: NSVisualEffectView.Material
    var backgroundTint: CGColor
    /// Fond opaque de toutes les surfaces de l'overlay : panneau latéral, panneau de l'encoche,
    /// pilule et bouton du widget de luminosité.
    var panelBackground: CGColor
    var strokeColor: CGColor

    /// Fond de la capsule de navigation, posée sous le panneau de l'encoche et détachée de lui.
    /// Translucide : elle flotte au-dessus du bureau, elle n'est pas un morceau de la silhouette.
    var tabCapsuleFill: CGColor

    /// Cercle de l'onglet actif dans la capsule. Franchement plus clair que la capsule qui le
    /// porte — c'est la seule chose qui désigne l'onglet choisi, les glyphes étant tous de la
    /// même taille. Distinct de `tabPillFill`, qui est la même marque posée sur le **panneau**,
    /// bien plus sombre : la même teinte aux deux endroits serait invisible à l'un ou criarde à
    /// l'autre.
    var tabCircleFill: CGColor

    var buttonSymbolColor: NSColor
    var buttonGlowColor: CGColor

    /// Pastille de l'onglet actif dans la barre du panneau, et les deux teintes de son contenu.
    /// L'onglet actif est franc sur sa pastille ; les autres restent en retrait, sans pastille.
    var tabPillFill: CGColor
    /// Teinte du glyphe posé **sur** la pastille. Distincte de `tabActiveContent`, qui est celle
    /// d'un contenu franc posé à même la capsule.
    var tabPillContent: NSColor
    var tabActiveContent: NSColor
    var tabInactiveContent: NSColor

    /// Accent et translucidité choisis dans les Préférences, poussés ici par
    /// `OverlayPaletteSettings`. Ils vivent sur le type plutôt que d'être passés en argument
    /// parce que toutes les vues de l'overlay appellent déjà `resolved(for:)` sans rien savoir
    /// des réglages : les y faire atterrir évite de tordre chaque `applyPalette()`.
    @MainActor static var accent: AccentColor = GeneralSettings().accentColor
    @MainActor static var panelOpacity: Double = GeneralSettings().panelOpacity

    /// Postée quand `accent` ou `panelOpacity` change. Les vues qui se repeignent déjà sur
    /// `viewDidChangeEffectiveAppearance` s'y abonnent pour la même raison.
    static let didChangeNotification = Notification.Name("whoa-stash.overlayPaletteDidChange")

    @MainActor
    static func resolved(for appearance: NSAppearance) -> OverlayPalette {
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return (isDark ? dark : light)
            .accented(with: accent, in: appearance)
            .fadingPanel(to: panelOpacity)
    }

    /// La palette brute d'une apparence, sans les réglages. Réservée aux tests, qui vérifient
    /// les transformations une par une.
    static func base(for appearance: NSAppearance) -> OverlayPalette {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
    }

    /// Vert d'accent de l'overlay. Partagé hors de la palette — le panneau de l'encoche
    /// s'en sert pour marquer la bague survolée — d'où sa visibilité interne.
    static let activeGreen = CGColor(red: 0x39 / 255, green: 0xFF / 255, blue: 0x88 / 255, alpha: 1)

    private static let dark = OverlayPalette(
        activeTickColor: activeGreen,
        inactiveTickColor: CGColor(gray: 0.55, alpha: 0.55),
        glowOpacity: 0.85,
        glowRadius: 4,
        backgroundMaterial: .hudWindow,
        backgroundTint: CGColor(gray: 0, alpha: 0.35),
        panelBackground: CGColor(gray: 0.04, alpha: 1),
        strokeColor: CGColor(gray: 1, alpha: 0.08),
        tabCapsuleFill: CGColor(gray: 0.12, alpha: 0.80),
        tabCircleFill: CGColor(gray: 0.42, alpha: 1),
        buttonSymbolColor: .white,
        buttonGlowColor: CGColor(gray: 1, alpha: 0.5),
        tabPillFill: CGColor(gray: 0.22, alpha: 1),
        tabPillContent: .white,
        tabActiveContent: .white,
        tabInactiveContent: NSColor(white: 0.62, alpha: 1)
    )

    private static let light = OverlayPalette(
        activeTickColor: activeGreen,
        inactiveTickColor: CGColor(gray: 0.45, alpha: 0.35),
        glowOpacity: 0.6,
        glowRadius: 3,
        backgroundMaterial: .popover,
        backgroundTint: CGColor(gray: 1, alpha: 0.4),
        panelBackground: CGColor(gray: 0.97, alpha: 1),
        strokeColor: CGColor(gray: 0, alpha: 0.06),
        tabCapsuleFill: CGColor(gray: 1, alpha: 0.80),
        tabCircleFill: CGColor(gray: 0.78, alpha: 1),
        buttonSymbolColor: .black.withAlphaComponent(0.75),
        buttonGlowColor: CGColor(gray: 0, alpha: 0.35),
        tabPillFill: CGColor(gray: 0.86, alpha: 1),
        tabPillContent: NSColor(white: 0.10, alpha: 1),
        tabActiveContent: NSColor(white: 0.10, alpha: 1),
        tabInactiveContent: NSColor(white: 0.42, alpha: 1)
    )
}

extension OverlayPalette {
    /// Applique le multiplicateur `Brightness > Glow intensity` des Préférences à une palette
    /// déjà résolue pour l'apparence courante.
    func scalingGlow(by intensity: Double) -> OverlayPalette {
        var palette = self
        palette.glowOpacity = Float(min(1, max(0, Double(glowOpacity) * intensity)))
        palette.glowRadius = glowRadius * CGFloat(intensity)
        return palette
    }

    /// Substitue la teinte d'accent choisie au vert historique — graduations actives du widget
    /// de luminosité, et plaque derrière la bague survolée du panneau de l'encoche.
    func accented(with accent: AccentColor, in appearance: NSAppearance) -> OverlayPalette {
        var palette = self
        palette.activeTickColor = accent.cgColor(for: appearance)
        return palette
    }

    /// Rend le fond des panneaux translucide. Les fenêtres sont déjà `isOpaque = false` et
    /// `backgroundColor = .clear`, donc abaisser l'alpha du fond peint laisse réellement voir
    /// à travers ; le filet et le contenu gardent le leur, sinon la silhouette se dissoudrait.
    func fadingPanel(to opacity: Double) -> OverlayPalette {
        guard opacity < 1 else { return self }
        var palette = self
        let clamped = max(0.2, min(1, opacity))
        palette.panelBackground = panelBackground.copy(alpha: CGFloat(clamped)) ?? panelBackground
        return palette
    }
}

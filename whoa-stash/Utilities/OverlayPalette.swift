import AppKit

/// Jeu de couleurs et de matériaux résolu pour une apparence donnée (clair/sombre).
/// Le vert des graduations actives est volontairement identique dans les deux palettes —
/// seul l'environnement autour de lui doit s'adapter.
struct OverlayPalette {
    let activeTickColor: CGColor
    let inactiveTickColor: CGColor
    let glowOpacity: Float
    let glowRadius: CGFloat

    let backgroundMaterial: NSVisualEffectView.Material
    let backgroundTint: CGColor
    let strokeColor: CGColor

    let buttonSymbolColor: NSColor
    let buttonGlowColor: CGColor

    static func resolved(for appearance: NSAppearance) -> OverlayPalette {
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return isDark ? .dark : .light
    }

    private static let activeGreen = CGColor(red: 0x39 / 255, green: 0xFF / 255, blue: 0x88 / 255, alpha: 1)

    private static let dark = OverlayPalette(
        activeTickColor: activeGreen,
        inactiveTickColor: CGColor(gray: 0.55, alpha: 0.55),
        glowOpacity: 0.85,
        glowRadius: 4,
        backgroundMaterial: .hudWindow,
        backgroundTint: CGColor(gray: 0, alpha: 0.35),
        strokeColor: CGColor(gray: 1, alpha: 0.08),
        buttonSymbolColor: .white,
        buttonGlowColor: CGColor(gray: 1, alpha: 0.5)
    )

    private static let light = OverlayPalette(
        activeTickColor: activeGreen,
        inactiveTickColor: CGColor(gray: 0.45, alpha: 0.35),
        glowOpacity: 0.6,
        glowRadius: 3,
        backgroundMaterial: .popover,
        backgroundTint: CGColor(gray: 1, alpha: 0.4),
        strokeColor: CGColor(gray: 0, alpha: 0.06),
        buttonSymbolColor: .black.withAlphaComponent(0.75),
        buttonGlowColor: CGColor(gray: 0, alpha: 0.35)
    )
}

extension OverlayPalette {
    /// Applique le multiplicateur `Brightness > Glow intensity` des Préférences à une palette
    /// déjà résolue pour l'apparence courante.
    func scalingGlow(by intensity: Double) -> OverlayPalette {
        OverlayPalette(
            activeTickColor: activeTickColor,
            inactiveTickColor: inactiveTickColor,
            glowOpacity: Float(min(1, max(0, Double(glowOpacity) * intensity))),
            glowRadius: glowRadius * CGFloat(intensity),
            backgroundMaterial: backgroundMaterial,
            backgroundTint: backgroundTint,
            strokeColor: strokeColor,
            buttonSymbolColor: buttonSymbolColor,
            buttonGlowColor: buttonGlowColor
        )
    }
}

import AppKit

/// Couleurs propres au widget d'utilisation Claude : un seul endroit décide de la teinte d'une
/// jauge, pour que la bague du Dock et les barres du panneau ne puissent pas diverger.
enum ClaudeUsagePalette {

    /// Vert identique à `OverlayPalette.activeTickColor` — le widget partage la signature
    /// colorée du reste de l'overlay plutôt que d'introduire un second vert.
    static let low = CGColor(red: 0x39 / 255, green: 0xFF / 255, blue: 0x88 / 255, alpha: 1)
    static let medium = CGColor(red: 0xFF / 255, green: 0xB8 / 255, blue: 0x3D / 255, alpha: 1)
    static let high = CGColor(red: 0xFF / 255, green: 0x4A / 255, blue: 0x23 / 255, alpha: 1)

    /// Seuils de bascule. Les deux points de la référence tombent de part et d'autre : 7 % en
    /// vert, 73 % en orange-rouge. Le palier ambre intermédiaire n'y apparaît pas — il évite
    /// qu'une jauge passe du vert au rouge d'un coup à mi-course.
    static let mediumThreshold = 0.50
    static let highThreshold = 0.70

    static func color(for utilization: Double) -> CGColor {
        switch utilization {
        case ..<mediumThreshold: return low
        case ..<highThreshold: return medium
        default: return high
        }
    }

    /// Piste (partie non remplie) d'une bague ou d'une barre.
    static func track(for appearance: NSAppearance) -> CGColor {
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return CGColor(gray: isDark ? 1 : 0, alpha: isDark ? 0.14 : 0.10)
    }

    /// Teinte neutre quand aucune donnée n'est disponible : la jauge reste lisible comme un
    /// contenant vide, sans suggérer « 0 % consommé ».
    static func unavailable(for appearance: NSAppearance) -> CGColor {
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return CGColor(gray: isDark ? 1 : 0, alpha: 0.28)
    }
}

/// Mise en forme des instants de réinitialisation, partagée par la bague (info-bulle) et le
/// panneau.
enum ClaudeUsageFormatting {

    private static let dayAndTime: DateFormatter = {
        let formatter = DateFormatter()
        // « Thu 12:00 AM » dans la référence ; `setLocalizedDateFormatFromTemplate` laisse les
        // locales 24 h afficher « jeu. 00:00 » au lieu d'imposer le format américain.
        formatter.setLocalizedDateFormatFromTemplate("EEE jmm")
        return formatter
    }()

    /// « Resets in 51 min », « Resets in 3 h », ou « Resets Thu 12:00 AM » au-delà de 24 h.
    static func resetText(for date: Date, now: Date = Date()) -> String {
        let remaining = date.timeIntervalSince(now)

        guard remaining > 0 else { return "Resetting now" }
        if remaining < 3600 {
            return "Resets in \(max(1, Int((remaining / 60).rounded(.up)))) min"
        }
        if remaining < 24 * 3600 {
            return "Resets in \(Int(remaining / 3600)) h"
        }
        return "Resets \(dayAndTime.string(from: date))"
    }
}

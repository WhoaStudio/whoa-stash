import AppKit

/// Bord de l'écran où un widget est ancré. Partagé par le slider de volume (`edgeSlider`)
/// et l'overlay de luminosité (`brightness.widgetPosition`).
enum EdgePosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case left
    case right

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: return "Left Edge"
        case .right: return "Right Edge"
        }
    }
}

/// Thème de l'interface. `.system` suit l'apparence macOS en direct.
enum AppearanceMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// `nil` laisse la fenêtre hériter de l'apparence de l'app / du système.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

/// Couleur d'accent de l'application. Une seule couleur est proposée aujourd'hui, mais le
/// type est prêt à accueillir de nouveaux cas (le picker s'étend automatiquement).
enum AccentColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case system

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        }
    }

    var color: NSColor {
        switch self {
        case .system: return .controlAccentColor
        }
    }
}

/// Taille du widget de luminosité.
enum WidgetSize: String, Codable, CaseIterable, Identifiable, Sendable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    var panelSize: NSSize {
        switch self {
        case .small: return NSSize(width: 108, height: 210)
        case .medium: return NSSize(width: 126, height: 260)
        case .large: return NSSize(width: 144, height: 320)
        }
    }
}

struct GeneralSettings: Codable, Equatable, Sendable {
    var launchAtLogin: Bool = false
    var appearanceMode: AppearanceMode = .system
    var accentColor: AccentColor = .system
    var enableAnimations: Bool = true
    var enableHapticFeedback: Bool = true
    var enableSoundFeedback: Bool = true
}

struct BrightnessSettings: Codable, Equatable, Sendable {
    var showPercentage: Bool = true
    /// Délai avant fermeture automatique une fois le curseur sorti du widget, en secondes.
    var autoHideDelay: Double = 0.2
    /// Multiplicateur d'intensité du glow (0...2, 1 = valeur par défaut de la palette).
    var glowIntensity: Double = 1.0
    /// Multiplicateur de la sensibilité au scroll (0.5...2.0, 1 = valeur par défaut).
    var scrollSensitivity: Double = 1.0
    var widgetPosition: EdgePosition = .left
    var widgetSize: WidgetSize = .medium
    var enableOverlay: Bool = true
}

struct DockExtensionSettings: Codable, Equatable, Sendable {
    static let slotCount = 5

    var isEnabled: Bool = true
    var slots: [DockExtensionSlot] = (0..<DockExtensionSettings.slotCount).map { DockExtensionSlot(index: $0, appPath: nil) }
    /// Côté du Dock où l'extension apparaît.
    var side: EdgePosition = .right

    init(
        isEnabled: Bool = true,
        slots: [DockExtensionSlot] = (0..<DockExtensionSettings.slotCount).map({ DockExtensionSlot(index: $0, appPath: nil) }),
        side: EdgePosition = .right
    ) {
        self.isEnabled = isEnabled
        self.slots = slots
        self.side = side
    }

    // Décodeur manuel : `side` est un champ ajouté après coup. Le JSON déjà persisté chez les
    // utilisateurs existants ne l'a pas, et le décodage synthétisé par défaut échouerait sur la
    // clé manquante (`try?` dans `SettingsStorage` réinitialiserait alors TOUT `AppSettings`,
    // pas seulement ce champ). `decodeIfPresent` + repli rend l'ajout rétro-compatible.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        slots = try container.decodeIfPresent([DockExtensionSlot].self, forKey: .slots)
            ?? (0..<DockExtensionSettings.slotCount).map { DockExtensionSlot(index: $0, appPath: nil) }
        side = try container.decodeIfPresent(EdgePosition.self, forKey: .side) ?? .right
    }
}

/// Réglages du slider de volume ancré au bord de l'écran — pas de section dédiée dans les
/// Préférences aujourd'hui, mais centralisés ici comme le reste.
struct EdgeSliderSettings: Codable, Equatable, Sendable {
    var edgePosition: EdgePosition = .right
    var sliderHeight: Double = 160
    var sensitivity: Double = 1.0
}

/// Racine unique des préférences de l'application, persistée automatiquement par
/// `SettingsStorage`. Aucune vue ni aucun contrôleur ne doit lire/écrire `UserDefaults`
/// directement — tout transite par ce modèle.
struct AppSettings: Codable, Equatable, Sendable {
    var general = GeneralSettings()
    var brightness = BrightnessSettings()
    var dock = DockExtensionSettings()
    var edgeSlider = EdgeSliderSettings()

    static let `default` = AppSettings()
}

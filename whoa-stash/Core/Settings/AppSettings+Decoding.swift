import Foundation

/// Décodage tolérant des préférences.
///
/// L'`init(from:)` synthétisé par Swift **lève** dès qu'une clé manque : il n'emprunte pas la
/// valeur par défaut de la propriété. Un blob écrit par une version antérieure, qui ne connaît
/// pas un réglage ajouté depuis, échouerait donc à se décoder — et comme `SettingsStorage`
/// retombe alors sur `.default`, l'utilisateur perdrait *toutes* ses préférences à chaque
/// version qui ajoute un réglage.
///
/// Chaque structure lit donc ses clés une à une, en retombant sur sa valeur par défaut quand
/// l'une manque ou n'est plus décodable (un cas d'énumération retiré, par exemple). Ajouter un
/// réglage ne casse plus rien, et en retirer un non plus.
private extension KeyedDecodingContainer {
    /// La valeur stockée sous `key`, ou `fallback` si elle est absente ou illisible.
    func value<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        guard let decoded = try? decodeIfPresent(T.self, forKey: key) else { return fallback }
        return decoded ?? fallback
    }
}

extension GeneralSettings {
    enum CodingKeys: String, CodingKey {
        case launchAtLogin
        case accentColor
        case enableAnimations
        case enableHapticFeedback
        case enableSoundFeedback
        case panelOpacity
        case togglePanelShortcut
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = GeneralSettings()
        self.init(
            launchAtLogin: container.value(.launchAtLogin, defaults.launchAtLogin),
            accentColor: container.value(.accentColor, defaults.accentColor),
            enableAnimations: container.value(.enableAnimations, defaults.enableAnimations),
            enableHapticFeedback: container.value(.enableHapticFeedback, defaults.enableHapticFeedback),
            enableSoundFeedback: container.value(.enableSoundFeedback, defaults.enableSoundFeedback),
            panelOpacity: container.value(.panelOpacity, defaults.panelOpacity),
            togglePanelShortcut: container.value(.togglePanelShortcut, defaults.togglePanelShortcut)
        )
    }
}

extension BrightnessSettings {
    enum CodingKeys: String, CodingKey {
        case showPercentage
        case autoHideDelay
        case glowIntensity
        case scrollSensitivity
        case widgetPosition
        case widgetSize
        case enableOverlay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = BrightnessSettings()
        self.init(
            showPercentage: container.value(.showPercentage, defaults.showPercentage),
            autoHideDelay: container.value(.autoHideDelay, defaults.autoHideDelay),
            glowIntensity: container.value(.glowIntensity, defaults.glowIntensity),
            scrollSensitivity: container.value(.scrollSensitivity, defaults.scrollSensitivity),
            widgetPosition: container.value(.widgetPosition, defaults.widgetPosition),
            widgetSize: container.value(.widgetSize, defaults.widgetSize),
            enableOverlay: container.value(.enableOverlay, defaults.enableOverlay)
        )
    }
}

extension EdgeSliderSettings {
    enum CodingKeys: String, CodingKey {
        case edgePosition
        case sliderHeight
        case sensitivity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = EdgeSliderSettings()
        self.init(
            edgePosition: container.value(.edgePosition, defaults.edgePosition),
            sliderHeight: container.value(.sliderHeight, defaults.sliderHeight),
            sensitivity: container.value(.sensitivity, defaults.sensitivity)
        )
    }
}

extension NotchPanelSettings {
    enum CodingKeys: String, CodingKey {
        case enabled
        case notchlessStyle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = NotchPanelSettings()
        self.init(
            enabled: container.value(.enabled, defaults.enabled),
            notchlessStyle: container.value(.notchlessStyle, defaults.notchlessStyle)
        )
    }
}

extension AppSettings {
    enum CodingKeys: String, CodingKey {
        case general
        case brightness
        case edgeSlider
        case notchPanel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        self.init(
            general: container.value(.general, defaults.general),
            brightness: container.value(.brightness, defaults.brightness),
            edgeSlider: container.value(.edgeSlider, defaults.edgeSlider),
            notchPanel: container.value(.notchPanel, defaults.notchPanel)
        )
    }
}

import Combine
import Foundation

/// Expose la section "General" à sa vue. Toute écriture passe par `SettingsStorage` ; l'effet
/// de bord système du lancement au démarrage est délégué à `LaunchAtLoginService`, jamais
/// déclenché depuis la vue.
@MainActor
final class GeneralSettingsViewModel: ObservableObject {

    private let storage: SettingsStorage
    private let launchAtLoginService: LaunchAtLoginService
    private var cancellable: AnyCancellable?
    private var notchPanelCancellable: AnyCancellable?

    @Published private(set) var settings: GeneralSettings
    /// Le panneau de l'encoche n'a pas de section à lui : son unique réglage est présenté
    /// dans « General », d'où ce second flux à côté de `settings`.
    @Published private(set) var notchPanel: NotchPanelSettings

    init(storage: SettingsStorage = .shared, launchAtLoginService: LaunchAtLoginService = .shared) {
        self.storage = storage
        self.launchAtLoginService = launchAtLoginService
        self.settings = storage.settings.general
        self.notchPanel = storage.settings.notchPanel

        cancellable = storage.$settings
            .map(\.general)
            .removeDuplicates()
            .sink { [weak self] in self?.settings = $0 }

        notchPanelCancellable = storage.$settings
            .map(\.notchPanel)
            .removeDuplicates()
            .sink { [weak self] in self?.notchPanel = $0 }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard settings.launchAtLogin != enabled else { return }
        storage.settings.general.launchAtLogin = enabled
        launchAtLoginService.setEnabled(enabled)
    }

    func setAppearanceMode(_ mode: AppearanceMode) {
        storage.settings.general.appearanceMode = mode
    }

    func setAccentColor(_ color: AccentColor) {
        storage.settings.general.accentColor = color
    }

    func setEnableAnimations(_ enabled: Bool) {
        storage.settings.general.enableAnimations = enabled
    }

    func setEnableHapticFeedback(_ enabled: Bool) {
        storage.settings.general.enableHapticFeedback = enabled
    }

    func setEnableSoundFeedback(_ enabled: Bool) {
        storage.settings.general.enableSoundFeedback = enabled
    }

    func setNotchPanelEnabled(_ enabled: Bool) {
        storage.settings.notchPanel.enabled = enabled
    }
}

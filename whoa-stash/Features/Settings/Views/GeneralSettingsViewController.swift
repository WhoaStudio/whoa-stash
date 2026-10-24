import AppKit
import Combine

/// Écran "General" : lancement au démarrage, apparence, couleur d'accent, animations,
/// retour haptique et sonore. Ne contient aucune logique — tout transite par
/// `GeneralSettingsViewModel`.
final class GeneralSettingsViewController: SettingsSectionViewController {

    private let viewModel = GeneralSettingsViewModel()
    private var cancellable: AnyCancellable?
    private var notchPanelCancellable: AnyCancellable?

    private let launchAtLoginSwitch = NSSwitch()
    private let appearancePopUp = NSPopUpButton()
    private let accentColorPopUp = NSPopUpButton()
    private let animationsSwitch = NSSwitch()
    private let hapticSwitch = NSSwitch()
    private let soundSwitch = NSSwitch()
    private let notchPanelSwitch = NSSwitch()

    override func makeCards() -> [SettingsCardView] {
        launchAtLoginSwitch.target = self
        launchAtLoginSwitch.action = #selector(launchAtLoginChanged)

        appearancePopUp.target = self
        appearancePopUp.action = #selector(appearanceChanged)
        AppearanceMode.allCases.forEach { appearancePopUp.addItem(withTitle: $0.displayName) }

        accentColorPopUp.target = self
        accentColorPopUp.action = #selector(accentColorChanged)
        AccentColor.allCases.forEach { accentColorPopUp.addItem(withTitle: $0.displayName) }

        animationsSwitch.target = self
        animationsSwitch.action = #selector(animationsChanged)

        hapticSwitch.target = self
        hapticSwitch.action = #selector(hapticChanged)

        soundSwitch.target = self
        soundSwitch.action = #selector(soundChanged)

        let startupCard = SettingsCardView(title: "Startup", rows: [
            SettingsRowView(title: "Launch at login", accessory: launchAtLoginSwitch),
        ])

        let appearanceCard = SettingsCardView(title: "Appearance", rows: [
            SettingsRowView(title: "Appearance", accessory: appearancePopUp),
            SettingsRowView(title: "Accent color", accessory: accentColorPopUp),
        ])

        notchPanelSwitch.target = self
        notchPanelSwitch.action = #selector(notchPanelChanged)

        let feedbackCard = SettingsCardView(title: "Feedback", rows: [
            SettingsRowView(title: "Enable animations", accessory: animationsSwitch),
            SettingsRowView(title: "Enable haptic feedback", accessory: hapticSwitch),
            SettingsRowView(title: "Enable sound feedback", accessory: soundSwitch),
        ])

        let notchPanelCard = SettingsCardView(title: "Notch Panel", rows: [
            SettingsRowView(title: "Show notch panel", accessory: notchPanelSwitch),
        ])

        return [startupCard, appearanceCard, notchPanelCard, feedbackCard]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        cancellable = viewModel.$settings.sink { [weak self] in self?.apply($0) }
        notchPanelCancellable = viewModel.$notchPanel.sink { [weak self] in
            self?.notchPanelSwitch.state = $0.enabled ? .on : .off
        }
    }

    private func apply(_ settings: GeneralSettings) {
        launchAtLoginSwitch.state = settings.launchAtLogin ? .on : .off
        appearancePopUp.selectItem(at: AppearanceMode.allCases.firstIndex(of: settings.appearanceMode) ?? 0)
        accentColorPopUp.selectItem(at: AccentColor.allCases.firstIndex(of: settings.accentColor) ?? 0)
        animationsSwitch.state = settings.enableAnimations ? .on : .off
        hapticSwitch.state = settings.enableHapticFeedback ? .on : .off
        soundSwitch.state = settings.enableSoundFeedback ? .on : .off
    }

    @objc private func launchAtLoginChanged() {
        viewModel.setLaunchAtLogin(launchAtLoginSwitch.state == .on)
    }

    @objc private func appearanceChanged() {
        viewModel.setAppearanceMode(AppearanceMode.allCases[appearancePopUp.indexOfSelectedItem])
    }

    @objc private func accentColorChanged() {
        viewModel.setAccentColor(AccentColor.allCases[accentColorPopUp.indexOfSelectedItem])
    }

    @objc private func animationsChanged() {
        viewModel.setEnableAnimations(animationsSwitch.state == .on)
    }

    @objc private func hapticChanged() {
        viewModel.setEnableHapticFeedback(hapticSwitch.state == .on)
    }

    @objc private func soundChanged() {
        viewModel.setEnableSoundFeedback(soundSwitch.state == .on)
    }

    @objc private func notchPanelChanged() {
        viewModel.setNotchPanelEnabled(notchPanelSwitch.state == .on)
    }
}

import AppKit
import Combine

/// Écran "General" : lancement au démarrage, couleur d'accent, translucidité des
/// panneaux, raccourci global, animations, retour haptique et sonore, et remise à zéro. Ne
/// contient aucune logique — tout transite par `GeneralSettingsViewModel`.
final class GeneralSettingsViewController: SettingsSectionViewController {

    private let viewModel = GeneralSettingsViewModel()
    private var cancellable: AnyCancellable?
    private var notchPanelCancellable: AnyCancellable?

    private let launchAtLoginSwitch = NSSwitch()
    private let accentColorPopUp = NSPopUpButton()
    private let animationsSwitch = NSSwitch()
    private let hapticSwitch = NSSwitch()
    private let soundSwitch = NSSwitch()
    private let notchPanelSwitch = NSSwitch()
    private let panelOpacitySlider = LabeledSliderView(minValue: 0.35, maxValue: 1, value: 1)
    private let shortcutPopUp = NSPopUpButton()
    private let notchlessStylePopUp = NSPopUpButton()
    private let resetButton = NSButton(title: "Reset…", target: nil, action: nil)

    override func makeCards() -> [SettingsCardView] {
        launchAtLoginSwitch.target = self
        launchAtLoginSwitch.action = #selector(launchAtLoginChanged)

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

        panelOpacitySlider.formatter = { String(format: "%.0f%%", $0 * 100) }
        panelOpacitySlider.onChange = { [weak self] in self?.viewModel.setPanelOpacity($0) }

        let appearanceCard = SettingsCardView(title: "Appearance", rows: [
            SettingsRowView(title: "Accent color", accessory: accentColorPopUp),
            SettingsRowView(title: "Panel opacity", accessory: panelOpacitySlider),
        ])

        notchPanelSwitch.target = self
        notchPanelSwitch.action = #selector(notchPanelChanged)

        shortcutPopUp.target = self
        shortcutPopUp.action = #selector(shortcutChanged)
        GlobalShortcut.allCases.forEach { shortcutPopUp.addItem(withTitle: $0.displayName) }

        notchlessStylePopUp.target = self
        notchlessStylePopUp.action = #selector(notchlessStyleChanged)
        NotchPanelStyle.allCases.forEach { notchlessStylePopUp.addItem(withTitle: $0.displayName) }

        resetButton.target = self
        resetButton.action = #selector(resetTapped)
        resetButton.bezelStyle = .rounded
        resetButton.translatesAutoresizingMaskIntoConstraints = false

        let feedbackCard = SettingsCardView(title: "Feedback", rows: [
            SettingsRowView(title: "Enable animations", accessory: animationsSwitch),
            SettingsRowView(title: "Enable haptic feedback", accessory: hapticSwitch),
            SettingsRowView(title: "Enable sound feedback", accessory: soundSwitch),
        ])

        let notchPanelCard = SettingsCardView(title: "Notch Panel", rows: [
            SettingsRowView(title: "Show notch panel", accessory: notchPanelSwitch),
            SettingsRowView(title: "Style without notch", accessory: notchlessStylePopUp),
            SettingsRowView(title: "Toggle shortcut", accessory: shortcutPopUp),
        ])

        let resetCard = SettingsCardView(title: "Reset", rows: [
            SettingsRowView(title: "Restore all settings to their defaults", accessory: resetButton),
        ])

        return [startupCard, appearanceCard, notchPanelCard, feedbackCard, resetCard]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        cancellable = viewModel.$settings.sink { [weak self] in self?.apply($0) }
        notchPanelCancellable = viewModel.$notchPanel.sink { [weak self] in
            self?.notchPanelSwitch.state = $0.enabled ? .on : .off
            self?.notchlessStylePopUp.selectItem(at: NotchPanelStyle.allCases.firstIndex(of: $0.notchlessStyle) ?? 0)
        }
    }

    private func apply(_ settings: GeneralSettings) {
        launchAtLoginSwitch.state = settings.launchAtLogin ? .on : .off
        accentColorPopUp.selectItem(at: AccentColor.allCases.firstIndex(of: settings.accentColor) ?? 0)
        animationsSwitch.state = settings.enableAnimations ? .on : .off
        hapticSwitch.state = settings.enableHapticFeedback ? .on : .off
        soundSwitch.state = settings.enableSoundFeedback ? .on : .off
        panelOpacitySlider.setValue(settings.panelOpacity)
        shortcutPopUp.selectItem(at: GlobalShortcut.allCases.firstIndex(of: settings.togglePanelShortcut) ?? 0)
    }

    @objc private func launchAtLoginChanged() {
        viewModel.setLaunchAtLogin(launchAtLoginSwitch.state == .on)
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

    @objc private func notchlessStyleChanged() {
        viewModel.setNotchlessStyle(NotchPanelStyle.allCases[notchlessStylePopUp.indexOfSelectedItem])
    }

    @objc private func shortcutChanged() {
        viewModel.setTogglePanelShortcut(GlobalShortcut.allCases[shortcutPopUp.indexOfSelectedItem])
    }

    /// Remise à zéro irréversible, donc confirmée : l'alerte est le seul endroit des
    /// Préférences où une action demande un accord avant d'agir.
    @objc private func resetTapped() {
        let alert = NSAlert()
        alert.messageText = "Restore default settings?"
        alert.informativeText = "Every setting goes back to its original value. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        viewModel.resetToDefaults()
    }
}

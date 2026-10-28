import AppKit
import Combine

/// Écran "Knock" : une action par motif de coups sur le châssis (simple, double) et la sensibilité.
final class KnockSettingsViewController: SettingsSectionViewController {

    private let viewModel = KnockSettingsViewModel()
    private var cancellable: AnyCancellable?

    private let enabledSwitch = NSSwitch()
    private let sensitivitySlider = LabeledSliderView(minValue: 0, maxValue: 1, value: 0.7)
    private let accessibilityButton = NSButton(title: "", target: nil, action: nil)
    private let singlePopUp = NSPopUpButton()
    private let doublePopUp = NSPopUpButton()

    override func makeCards() -> [SettingsCardView] {
        enabledSwitch.target = self
        enabledSwitch.action = #selector(enabledChanged)

        sensitivitySlider.formatter = { String(format: "%.0f%%", $0 * 100) }
        sensitivitySlider.onChange = { [weak self] in self?.viewModel.setSensitivity($0) }

        accessibilityButton.bezelStyle = .rounded
        accessibilityButton.target = self
        accessibilityButton.action = #selector(accessibilityTapped)

        for popUp in [singlePopUp, doublePopUp] {
            KnockAction.allCases.forEach { popUp.addItem(withTitle: $0.displayName) }
            popUp.target = self
            popUp.action = #selector(actionChanged(_:))
        }

        let generalCard = SettingsCardView(title: "Knock detection", rows: [
            SettingsRowView(title: "Enable knock detection", subtitle: "Knock on the Mac's body, next to the keyboard", accessory: enabledSwitch),
            SettingsRowView(title: "Sensitivity", subtitle: "Higher picks up lighter knocks", accessory: sensitivitySlider),
            SettingsRowView(title: "Accessibility", subtitle: "Needed only by Lock screen", accessory: accessibilityButton),
        ])
        let actionsCard = SettingsCardView(title: "Actions", rows: [
            SettingsRowView(title: "Single knock", accessory: singlePopUp),
            SettingsRowView(title: "Double knock", accessory: doublePopUp),
        ])
        return [generalCard, actionsCard]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        cancellable = viewModel.$settings.sink { [weak self] in self?.apply($0) }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshAccessibility()
    }

    private func apply(_ settings: KnockSettings) {
        enabledSwitch.state = settings.enabled ? .on : .off
        sensitivitySlider.setValue(settings.sensitivity)
        singlePopUp.selectItem(at: KnockAction.allCases.firstIndex(of: settings.single) ?? 0)
        doublePopUp.selectItem(at: KnockAction.allCases.firstIndex(of: settings.double) ?? 0)
        for control in [singlePopUp, doublePopUp] { control.isEnabled = settings.enabled }
        refreshAccessibility()
    }

    private func refreshAccessibility() {
        let trusted = AccessibilityPermissionService.shared.isTrusted
        accessibilityButton.title = trusted ? "Granted" : "Grant access…"
        accessibilityButton.isEnabled = !trusted
    }

    @objc private func enabledChanged() {
        viewModel.setEnabled(enabledSwitch.state == .on)
    }

    @objc private func actionChanged(_ sender: NSPopUpButton) {
        viewModel.setAction(KnockAction.allCases[sender.indexOfSelectedItem], taps: sender === singlePopUp ? 1 : 2)
    }

    @objc private func accessibilityTapped() {
        AccessibilityPermissionService.shared.requestAccess()
        AccessibilityPermissionService.shared.openSystemSettings()
    }
}

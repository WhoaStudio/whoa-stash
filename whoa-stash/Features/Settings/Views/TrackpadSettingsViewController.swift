import AppKit
import Combine

/// Écran "Trackpad" : une action par côté (gauche/droite) et nombre de taps (simple/double).
final class TrackpadSettingsViewController: SettingsSectionViewController {

    private let viewModel = TrackpadSettingsViewModel()
    private var cancellable: AnyCancellable?

    private let enabledSwitch = NSSwitch()
    private let accessibilityButton = NSButton(title: "", target: nil, action: nil)

    private struct Slot {
        let side: TrackpadSide
        let taps: Int
        let popUp = NSPopUpButton()
    }
    private let slots = [
        Slot(side: .left, taps: 1), Slot(side: .left, taps: 2),
        Slot(side: .right, taps: 1), Slot(side: .right, taps: 2),
    ]

    override func makeCards() -> [SettingsCardView] {
        enabledSwitch.target = self
        enabledSwitch.action = #selector(enabledChanged)

        accessibilityButton.bezelStyle = .rounded
        accessibilityButton.target = self
        accessibilityButton.action = #selector(accessibilityTapped)

        for slot in slots {
            EdgeTapAction.allCases.forEach { slot.popUp.addItem(withTitle: $0.displayName) }
            slot.popUp.target = self
            slot.popUp.action = #selector(actionChanged(_:))
        }

        let generalCard = SettingsCardView(title: "Edge taps", rows: [
            SettingsRowView(title: "Enable edge taps", subtitle: "Tap the left or right edge of the trackpad", accessory: enabledSwitch),
            SettingsRowView(title: "Accessibility", subtitle: "Needed only by Lock screen", accessory: accessibilityButton),
        ])
        let titles = ["Left edge, single tap", "Left edge, double tap", "Right edge, single tap", "Right edge, double tap"]
        let actionsCard = SettingsCardView(title: "Actions", rows: zip(titles, slots).map {
            SettingsRowView(title: $0, accessory: $1.popUp)
        })
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

    private func apply(_ settings: TrackpadGestureSettings) {
        enabledSwitch.state = settings.enabled ? .on : .off
        for slot in slots {
            let action = settings.action(side: slot.side, taps: slot.taps)
            slot.popUp.selectItem(at: EdgeTapAction.allCases.firstIndex(of: action) ?? 0)
            slot.popUp.isEnabled = settings.enabled
        }
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
        guard let slot = slots.first(where: { $0.popUp === sender }) else { return }
        viewModel.setAction(EdgeTapAction.allCases[sender.indexOfSelectedItem], side: slot.side, taps: slot.taps)
    }

    @objc private func accessibilityTapped() {
        AccessibilityPermissionService.shared.requestAccess()
        AccessibilityPermissionService.shared.openSystemSettings()
    }
}

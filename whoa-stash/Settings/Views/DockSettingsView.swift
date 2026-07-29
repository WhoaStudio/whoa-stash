import AppKit
import Combine

/// Écran "Dock Extension" : activation globale, puis un slot par emplacement (icône +
/// chemin de l'app choisie, bouton "Choose…", bouton "Clear" quand un slot n'est pas vide).
final class DockSettingsView: SettingsSectionViewController {

    private let viewModel = DockSettingsViewModel()
    private var cancellable: AnyCancellable?

    private let enableSwitch = NSSwitch()
    private let sidePopUp = NSPopUpButton()
    private var slotRows: [DockSlotRowView] = []

    override func makeCards() -> [SettingsCardView] {
        enableSwitch.target = self
        enableSwitch.action = #selector(enableChanged)

        sidePopUp.target = self
        sidePopUp.action = #selector(sideChanged)
        EdgePosition.allCases.forEach { sidePopUp.addItem(withTitle: $0.displayName) }

        let enableCard = SettingsCardView(title: "Dock Extension", rows: [
            SettingsRowView(title: "Enable Dock Extension", accessory: enableSwitch),
            SettingsRowView(title: "Position", accessory: sidePopUp),
        ])

        slotRows = (0..<DockExtensionSettings.slotCount).map { index in
            let row = DockSlotRowView(slotLabel: "Slot \(index + 1)")
            row.onChoose = { [weak self] in self?.chooseApp(at: index) }
            row.onClear = { [weak self] in self?.clearApp(at: index) }
            return row
        }

        let slotsCard = SettingsCardView(title: "Applications", rows: slotRows)

        return [enableCard, slotsCard]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        cancellable = viewModel.$settings.sink { [weak self] in self?.apply($0) }
    }

    private func apply(_ settings: DockExtensionSettings) {
        enableSwitch.state = settings.isEnabled ? .on : .off
        sidePopUp.selectItem(at: EdgePosition.allCases.firstIndex(of: settings.side) ?? 0)
        for (index, slot) in settings.slots.enumerated() where slotRows.indices.contains(index) {
            slotRows[index].configure(
                icon: viewModel.icon(for: slot),
                name: viewModel.name(for: slot),
                isEmpty: slot.appPath == nil
            )
        }
    }

    private func chooseApp(at index: Int) {
        guard viewModel.settings.slots.indices.contains(index) else { return }
        viewModel.chooseApp(for: viewModel.settings.slots[index])
    }

    private func clearApp(at index: Int) {
        guard viewModel.settings.slots.indices.contains(index) else { return }
        viewModel.clearApp(for: viewModel.settings.slots[index])
    }

    @objc private func enableChanged() {
        viewModel.setEnabled(enableSwitch.state == .on)
    }

    @objc private func sideChanged() {
        viewModel.setSide(EdgePosition.allCases[sidePopUp.indexOfSelectedItem])
    }
}

/// Une ligne "Slot N" : icône + nom de l'app choisie, bouton "Choose…", bouton "Clear"
/// affiché uniquement quand le slot n'est pas vide.
private final class DockSlotRowView: NSView, SettingsCardRow {

    var onChoose: (() -> Void)?
    var onClear: (() -> Void)?

    private let slotLabel = NSTextField(labelWithString: "")
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let chooseButton = NSButton(title: "Choose…", target: nil, action: nil)
    private let clearButton = NSButton(title: "Clear", target: nil, action: nil)
    private let separator = NSBox()

    var showsSeparator: Bool {
        get { !separator.isHidden }
        set { separator.isHidden = !newValue }
    }

    init(slotLabel text: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        slotLabel.stringValue = text
        slotLabel.font = .systemFont(ofSize: 13)
        slotLabel.textColor = .secondaryLabelColor

        iconView.imageScaling = .scaleProportionallyUpOrDown

        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.lineBreakMode = .byTruncatingMiddle

        chooseButton.bezelStyle = .rounded
        chooseButton.controlSize = .small
        chooseButton.target = self
        chooseButton.action = #selector(chooseTapped)

        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .small
        clearButton.target = self
        clearButton.action = #selector(clearTapped)

        separator.boxType = .separator
        separator.fillColor = SettingsPalette.rowSeparator

        [slotLabel, iconView, nameLabel, chooseButton, clearButton, separator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        let inset = SettingsMetrics.rowHorizontalPadding

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: SettingsMetrics.rowMinHeight),

            slotLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            slotLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            slotLabel.widthAnchor.constraint(equalToConstant: 52),

            iconView.leadingAnchor.constraint(equalTo: slotLabel.trailingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: chooseButton.leadingAnchor, constant: -12),

            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            clearButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            chooseButton.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -8),
            chooseButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(icon: NSImage?, name: String, isEmpty: Bool) {
        iconView.image = icon
        iconView.isHidden = icon == nil
        nameLabel.stringValue = name
        nameLabel.textColor = isEmpty ? .secondaryLabelColor : .labelColor
        clearButton.isHidden = isEmpty
    }

    @objc private func chooseTapped() { onChoose?() }
    @objc private func clearTapped() { onClear?() }
}

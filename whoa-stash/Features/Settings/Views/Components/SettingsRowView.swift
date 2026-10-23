import AppKit

/// Une ligne de réglage : titre (+ sous-titre optionnel) à gauche, contrôle natif à droite,
/// séparateur fin en bas — l'unité de base de chaque `SettingsCardView`.
final class SettingsRowView: NSView, SettingsCardRow {

    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let accessoryContainer = NSView()
    private let separator = NSBox()

    var showsSeparator: Bool {
        get { !separator.isHidden }
        set { separator.isHidden = !newValue }
    }

    init(title: String, subtitle: String? = nil, accessory: NSView) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.stringValue = subtitle ?? ""
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.isHidden = subtitle == nil

        separator.boxType = .separator
        separator.fillColor = SettingsPalette.rowSeparator

        let textStack = NSStackView(views: subtitle == nil ? [titleLabel] : [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        accessoryContainer.translatesAutoresizingMaskIntoConstraints = false
        accessoryContainer.addSubview(accessory)
        accessory.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            accessory.topAnchor.constraint(greaterThanOrEqualTo: accessoryContainer.topAnchor),
            accessory.bottomAnchor.constraint(lessThanOrEqualTo: accessoryContainer.bottomAnchor),
            accessory.centerYAnchor.constraint(equalTo: accessoryContainer.centerYAnchor),
            accessory.trailingAnchor.constraint(equalTo: accessoryContainer.trailingAnchor),
            accessory.leadingAnchor.constraint(greaterThanOrEqualTo: accessoryContainer.leadingAnchor),
        ])

        addSubview(textStack)
        addSubview(accessoryContainer)
        addSubview(separator)
        separator.translatesAutoresizingMaskIntoConstraints = false

        let inset = SettingsMetrics.rowHorizontalPadding

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: SettingsMetrics.rowMinHeight),

            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: accessoryContainer.leadingAnchor, constant: -12),

            accessoryContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            accessoryContainer.topAnchor.constraint(equalTo: topAnchor),
            accessoryContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            accessoryContainer.widthAnchor.constraint(lessThanOrEqualToConstant: SettingsMetrics.rowControlWidth),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

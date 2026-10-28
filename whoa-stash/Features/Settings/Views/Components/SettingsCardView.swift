import AppKit

/// Une ligne pouvant être hébergée par `SettingsCardView` : `SettingsRowView` (titre +
/// contrôle) ou une ligne au contenu plus spécifique.
protocol SettingsCardRow: NSView {
    var showsSeparator: Bool { get set }
}

/// Un groupe de réglages : titre discret au-dessus, carte translucide aux coins très
/// arrondis en dessous, une ligne par réglage. L'unité de mise en page principale de
/// chaque écran de Préférences.
final class SettingsCardView: NSView {

    private let headerLabel = NSTextField(labelWithString: "")
    private let background = NSVisualEffectView()
    private let stackView = NSStackView()

    init(title: String? = nil, rows: [SettingsCardRow]) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        headerLabel.stringValue = title?.uppercased() ?? ""
        headerLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        headerLabel.textColor = .secondaryLabelColor
        headerLabel.isHidden = title == nil

        background.material = SettingsPalette.cardMaterial
        background.blendingMode = .withinWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = SettingsMetrics.cardCornerRadius
        background.layer?.cornerCurve = .continuous
        background.layer?.masksToBounds = true

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        rows.last?.showsSeparator = false
        rows.forEach { stackView.addArrangedSubview($0) }

        background.addSubview(stackView)
        addSubview(headerLabel)
        addSubview(background)

        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        background.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            headerLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),

            background.topAnchor.constraint(equalTo: title == nil ? topAnchor : headerLabel.bottomAnchor, constant: title == nil ? 0 : SettingsMetrics.cardHeaderSpacing),
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.topAnchor.constraint(equalTo: background.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])

        for row in rows {
            row.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

import AppKit

/// Une entrée de la sidebar : icône SF Symbol + texte, cible d'un clic. La mise en évidence
/// de l'état sélectionné est peinte par `SidebarView` (un fond unique qui se déplace d'une
/// entrée à l'autre), pas par cette vue elle-même.
final class SidebarItemView: NSView {

    let category: SettingsCategory
    var onClick: ((SettingsCategory) -> Void)?

    private let iconTile: IconTileView
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    init(category: SettingsCategory) {
        self.category = category
        self.iconTile = IconTileView(color: category.tintColor)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        iconTile.wantsLayer = true
        iconTile.layer?.cornerRadius = SettingsMetrics.sidebarIconTileCornerRadius
        iconTile.layer?.cornerCurve = .continuous
        iconTile.translatesAutoresizingMaskIntoConstraints = false

        let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        iconView.image = NSImage(systemSymbolName: category.symbolName, accessibilityDescription: category.title)?
            .withSymbolConfiguration(config)
        // Blanc fixe (pas `.labelColor`) : le fond de la tuile est une couleur saturée propre à
        // la catégorie, pas une surface neutre qui suit le clair/sombre — il faut un contraste
        // constant par-dessus.
        iconView.contentTintColor = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false

        label.stringValue = category.title
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        iconTile.addSubview(iconView)
        addSubview(iconTile)
        addSubview(label)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: SettingsMetrics.sidebarItemHeight),

            iconTile.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconTile.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconTile.widthAnchor.constraint(equalToConstant: SettingsMetrics.sidebarIconTileSize),
            iconTile.heightAnchor.constraint(equalToConstant: SettingsMetrics.sidebarIconTileSize),

            iconView.centerXAnchor.constraint(equalTo: iconTile.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconTile.centerYAnchor),

            label.leadingAnchor.constraint(equalTo: iconTile.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(click)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleClick() {
        onClick?(category)
    }
}

/// Tuile arrondie derrière chaque icône de la sidebar, teintée par catégorie. Voir
/// `SidebarSelectionView` pour la raison du couple `wantsUpdateLayer`/`updateLayer` : une
/// simple assignation de `cgColor` ne suit pas les changements clair/sombre.
private final class IconTileView: NSView {
    private let color: NSColor

    init(color: NSColor) {
        self.color = color
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = color.cgColor
    }
}

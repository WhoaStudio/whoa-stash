import AppKit
import Combine

/// Barre d'onglets des Préférences : une entrée par `SettingsCategory`, icône au-dessus du
/// libellé, centrées sous le titre de la fenêtre. L'onglet sélectionné porte un fond clair.
final class SettingsTabBarView: NSView {

    private let viewModel: SettingsViewModel
    private let animationsEnabled: () -> Bool
    private var items: [SettingsTabItemView] = []
    private var cancellable: AnyCancellable?

    init(viewModel: SettingsViewModel, animationsEnabled: @escaping () -> Bool) {
        self.viewModel = viewModel
        self.animationsEnabled = animationsEnabled
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        items = SettingsCategory.allCases.map { category in
            let item = SettingsTabItemView(category: category)
            item.onClick = { [weak self] in self?.viewModel.selectedCategory = $0 }
            return item
        }

        let stack = NSStackView(views: items)
        stack.orientation = .horizontal
        stack.spacing = SettingsMetrics.tabItemSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        let rule = NSBox()
        rule.boxType = .separator
        rule.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        addSubview(rule)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: SettingsMetrics.tabBarHeight),

            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),

            rule.leadingAnchor.constraint(equalTo: leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: trailingAnchor),
            rule.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        var isFirst = true
        cancellable = viewModel.$selectedCategory.sink { [weak self] category in
            guard let self else { return }
            let animated = !isFirst && animationsEnabled()
            isFirst = false
            items.forEach { $0.setSelected($0.category == category, animated: animated) }
        }
    }
}

/// Un onglet : icône SF Symbol au-dessus du libellé, cible d'un clic.
private final class SettingsTabItemView: NSView {

    let category: SettingsCategory
    var onClick: ((SettingsCategory) -> Void)?

    private let background = SettingsFillView(
        fill: SettingsPalette.selectedFill, cornerRadius: SettingsMetrics.tabItemCornerRadius)
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    init(category: SettingsCategory) {
        self.category = category
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        background.alphaValue = 0

        let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        iconView.image = NSImage(systemSymbolName: category.symbolName, accessibilityDescription: category.title)?
            .withSymbolConfiguration(config)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        label.stringValue = category.title
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(background)
        addSubview(iconView)
        addSubview(label)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: SettingsMetrics.tabItemSize.width),
            heightAnchor.constraint(equalToConstant: SettingsMetrics.tabItemSize.height),

            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),

            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 10),

            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])

        addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(handleClick)))
        setSelected(false, animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSelected(_ selected: Bool, animated: Bool) {
        label.font = .systemFont(ofSize: 13, weight: selected ? .semibold : .medium)
        label.textColor = selected ? .labelColor : .secondaryLabelColor
        iconView.contentTintColor = selected ? .labelColor : .secondaryLabelColor

        let alpha: CGFloat = selected ? 1 : 0
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = SettingsMetrics.transitionDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                background.animator().alphaValue = alpha
            }
        } else {
            background.alphaValue = alpha
        }
    }

    @objc private func handleClick() {
        onClick?(category)
    }
}

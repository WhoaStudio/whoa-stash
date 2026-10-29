import AppKit

/// Une ligne de formulaire : libellé aligné à droite dans une colonne fixe, contrôle à sa
/// droite, légende optionnelle sous le contrôle. L'unité de base de chaque écran de Préférences.
final class SettingsFormRowView: NSView {

    private let titleLabel = NSTextField(labelWithString: "")
    private let control: NSView

    /// Atténue le libellé et le contrôle quand le réglage n'a pas d'effet pour l'instant.
    var isDimmed = false {
        didSet {
            titleLabel.textColor = isDimmed ? .tertiaryLabelColor : .secondaryLabelColor
            control.alphaValue = isDimmed ? 0.5 : 1
        }
    }

    /// - Parameter alignsTop: `true` pour un contrôle haut (choix à vignettes, bannière) collé en
    ///   haut de la ligne ; sinon il est centré sur la première ligne, comme le libellé.
    init(title: String? = nil, control: NSView, caption: String? = nil, alignsTop: Bool = false) {
        self.control = control
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.stringValue = title ?? ""
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.alignment = .right
        titleLabel.isHidden = title == nil
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        control.translatesAutoresizingMaskIntoConstraints = false
        let slot = NSView()
        slot.translatesAutoresizingMaskIntoConstraints = false
        slot.addSubview(control)

        var columnViews: [NSView] = [slot]
        if let caption {
            let captionLabel = NSTextField(wrappingLabelWithString: caption)
            captionLabel.font = .systemFont(ofSize: 11)
            captionLabel.textColor = .tertiaryLabelColor
            captionLabel.preferredMaxLayoutWidth = SettingsMetrics.captionMaxWidth
            columnViews.append(captionLabel)
        }
        let column = NSStackView(views: columnViews)
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = SettingsMetrics.captionSpacing
        column.translatesAutoresizingMaskIntoConstraints = false

        let firstLine = NSLayoutGuide()
        addLayoutGuide(firstLine)
        addSubview(titleLabel)
        addSubview(column)

        NSLayoutConstraint.activate([
            firstLine.topAnchor.constraint(equalTo: topAnchor),
            firstLine.heightAnchor.constraint(equalToConstant: SettingsMetrics.firstLineHeight),

            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: leadingAnchor, constant: SettingsMetrics.labelColumnWidth),
            titleLabel.centerYAnchor.constraint(equalTo: firstLine.centerYAnchor),

            column.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: SettingsMetrics.labelColumnWidth + SettingsMetrics.labelControlGap),
            column.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),

            slot.heightAnchor.constraint(greaterThanOrEqualToConstant: SettingsMetrics.firstLineHeight),
            control.leadingAnchor.constraint(equalTo: slot.leadingAnchor),
            control.trailingAnchor.constraint(equalTo: slot.trailingAnchor),
            control.topAnchor.constraint(greaterThanOrEqualTo: slot.topAnchor),
            control.bottomAnchor.constraint(lessThanOrEqualTo: slot.bottomAnchor),
            alignsTop
                ? control.topAnchor.constraint(equalTo: slot.topAnchor)
                : control.centerYAnchor.constraint(equalTo: slot.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// Filet horizontal entre deux groupes de réglages.
func makeSettingsDivider() -> NSView {
    let rule = NSBox()
    rule.boxType = .separator
    rule.translatesAutoresizingMaskIntoConstraints = false
    return rule
}

extension NSButton {
    /// Case à cocher du formulaire — `state == .on` comme l'`NSSwitch` qu'elle remplace.
    static func settingsCheckbox(_ title: String, target: AnyObject, action: Selector) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: target, action: action)
        button.font = .systemFont(ofSize: 13)
        return button
    }
}

/// Pile verticale de contrôles courts (cases à cocher) dans une seule ligne de formulaire.
func makeSettingsControlStack(_ views: [NSView]) -> NSStackView {
    let stack = NSStackView(views: views)
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 8
    return stack
}

/// Bouton large à fond gris qui affiche le raccourci choisi (« ⌘ Space »), menu au clic.
final class SettingsKeyPopUp: NSPopUpButton {

    init() {
        super.init(frame: .zero, pullsDown: false)
        isBordered = false
        font = .systemFont(ofSize: 15, weight: .semibold)
        alignment = .center
        (cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        updateBackground()
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: SettingsMetrics.keyButtonSize.width),
            heightAnchor.constraint(equalToConstant: SettingsMetrics.keyButtonSize.height),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackground()
    }

    private func updateBackground() {
        layer?.backgroundColor = SettingsPalette.fill.cgColor
    }
}

import AppKit

/// Carte de l'onglet AI qui montre ce que Claude demande : le projet, l'outil, puis la commande ou
/// le fichier — ou la question et ses choix. Elle prend la place de la carte d'utilisation tant
/// qu'une demande attend.
///
/// Quand la demande attend une réponse (`replyID`), des boutons répondent depuis l'encoche : Allow et
/// Deny pour un outil, un bouton par choix pour une question simple. Sinon (plusieurs questions,
/// choix multiples, simple notification), la réponse se donne dans Claude Code.
final class AgentPromptCardView: NSView {

    var onDecision: ((AgentEvent, AgentEvent.Decision) -> Void)?

    private var event: AgentEvent?
    private var buttons: [PromptButton] = []
    private let hintLabel = NSTextField(labelWithString: "Answer in Claude Code")
    private let buttonHeight: CGFloat = 30

    private let dotView = NSView()
    private let projectLabel = NSTextField(labelWithString: "")
    private let sourceLabel = NSTextField(labelWithString: "Claude Code")
    private let kindLabel = NSTextField(labelWithString: "")
    private let bodyBox = NSView()
    private let bodyLabel = NSTextField(wrappingLabelWithString: "")

    private let inset: CGFloat = 18

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.07).cgColor

        dotView.wantsLayer = true
        dotView.layer?.backgroundColor = NSColor.systemOrange.cgColor
        dotView.layer?.cornerRadius = 4

        projectLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        projectLabel.textColor = .white
        projectLabel.lineBreakMode = .byTruncatingTail
        sourceLabel.font = .systemFont(ofSize: 12, weight: .regular)
        sourceLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        kindLabel.font = .systemFont(ofSize: 12, weight: .medium)
        kindLabel.textColor = .systemOrange
        kindLabel.alignment = .right

        bodyBox.wantsLayer = true
        bodyBox.layer?.cornerRadius = 12
        bodyBox.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
        bodyLabel.isSelectable = false
        bodyLabel.maximumNumberOfLines = 0
        bodyLabel.lineBreakMode = .byTruncatingTail
        bodyBox.addSubview(bodyLabel)

        hintLabel.font = .systemFont(ofSize: 11, weight: .regular)
        hintLabel.textColor = NSColor.white.withAlphaComponent(0.45)
        hintLabel.alignment = .center
        [dotView, projectLabel, sourceLabel, kindLabel, bodyBox, hintLabel].forEach(addSubview)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ event: AgentEvent) {
        self.event = event
        rebuildButtons(for: event)
        projectLabel.stringValue = event.project
        let body = NSMutableAttributedString()
        let mono = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        let plain: [NSAttributedString.Key: Any] = [.font: mono, .foregroundColor: NSColor.white.withAlphaComponent(0.9)]
        let bold: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.white,
        ]
        let dim: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.6),
        ]

        switch event.prompt {
        case .tool(let name, let detail):
            kindLabel.stringValue = "Permission · \(name)"
            body.append(NSAttributedString(string: detail.isEmpty ? name : detail, attributes: plain))
        case .questions(let questions):
            kindLabel.stringValue = questions.count > 1 ? "\(questions.count) questions" : "Question"
            for (index, question) in questions.enumerated() {
                if index > 0 { body.append(NSAttributedString(string: "\n\n", attributes: plain)) }
                body.append(NSAttributedString(string: question.text, attributes: bold))
                for option in question.options {
                    body.append(NSAttributedString(string: "\n\(question.multiSelect ? "☐" : "○") \(option.label)", attributes: bold))
                    if !option.detail.isEmpty {
                        body.append(NSAttributedString(string: "  \(option.detail)", attributes: dim))
                    }
                }
            }
        case .message(let text):
            kindLabel.stringValue = "Needs input"
            body.append(NSAttributedString(string: text, attributes: [.font: bold[.font]!, .foregroundColor: NSColor.white]))
        case nil:
            kindLabel.stringValue = ""
        }
        bodyLabel.attributedStringValue = body
        needsLayout = true
    }

    /// Les actions que la demande permet depuis l'encoche ; vide quand la réponse reste dans Claude Code.
    private func actions(for event: AgentEvent) -> [(title: String, style: PromptButton.Style, decision: AgentEvent.Decision)] {
        guard event.replyID != nil else { return [] }
        switch event.prompt {
        case .tool:
            return [("Deny", .secondary, .deny), ("Allow", .primary, .allow)]
        case .questions(let questions):
            guard questions.count == 1, let question = questions.first, !question.multiSelect else { return [] }
            return question.options.prefix(4).map {
                ($0.label, .primary, .answer([question.text: $0.label]))
            }
        default:
            return []
        }
    }

    private func rebuildButtons(for event: AgentEvent) {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = actions(for: event).map { action in
            let button = PromptButton(title: action.title, style: action.style)
            button.onClick = { [weak self] in
                guard let self, let event = self.event else { return }
                self.onDecision?(event, action.decision)
            }
            addSubview(button)
            return button
        }
        hintLabel.isHidden = !buttons.isEmpty
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let top = bounds.maxY - 14
        dotView.frame = NSRect(x: inset, y: top - 16 + 5, width: 8, height: 8)
        projectLabel.sizeToFit()
        let nameWidth = min(projectLabel.frame.width, bounds.width * 0.4)
        projectLabel.frame = NSRect(x: dotView.frame.maxX + 8, y: top - 18, width: nameWidth, height: 18)
        sourceLabel.frame = NSRect(x: projectLabel.frame.maxX + 8, y: top - 17, width: 100, height: 16)
        let kindX = bounds.width * 0.5
        kindLabel.frame = NSRect(x: kindX, y: top - 17, width: bounds.width - kindX - inset, height: 16)

        let boxTop = top - 26
        let footer: CGFloat = buttons.isEmpty ? 22 : buttonHeight + 10
        let boxBottom = 12 + footer
        bodyBox.frame = NSRect(
            x: inset, y: boxBottom, width: bounds.width - 2 * inset, height: max(0, boxTop - boxBottom))
        hintLabel.frame = NSRect(x: inset, y: 12, width: bounds.width - 2 * inset, height: 14)
        if !buttons.isEmpty {
            let gap: CGFloat = 8
            let width = (bounds.width - 2 * inset - gap * CGFloat(buttons.count - 1)) / CGFloat(buttons.count)
            for (index, button) in buttons.enumerated() {
                button.frame = NSRect(
                    x: inset + CGFloat(index) * (width + gap), y: 12, width: width, height: buttonHeight)
            }
        }
        bodyLabel.preferredMaxLayoutWidth = bodyBox.bounds.width - 20
        bodyLabel.frame = bodyBox.bounds.insetBy(dx: 10, dy: 8)
    }
}


/// Bouton plat de la carte : fond arrondi, plus clair au survol.
private final class PromptButton: NSView {

    enum Style { case primary, secondary }

    var onClick: (() -> Void)?

    private let style: Style
    private let label: NSTextField
    private var isHovered = false { didSet { updateBackground() } }

    init(title: String, style: Style) {
        self.style = style
        label = NSTextField(labelWithString: title)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = style == .primary ? .black : .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)
        updateBackground()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let height = label.intrinsicContentSize.height
        label.frame = NSRect(x: 8, y: (bounds.height - height) / 2, width: max(0, bounds.width - 16), height: height)
    }

    private func updateBackground() {
        let base: NSColor = style == .primary ? .systemOrange : NSColor.white.withAlphaComponent(0.14)
        layer?.backgroundColor = (isHovered ? base.withAlphaComponent(style == .primary ? 0.85 : 0.24) : base).cgColor
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

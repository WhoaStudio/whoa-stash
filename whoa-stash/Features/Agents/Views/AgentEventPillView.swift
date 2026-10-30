import AppKit

/// Contenu des deux ailes que l'encoche ouvre quand un agent IA termine ou attend : le glyphe et le
/// nom du projet à gauche, l'état à droite. Le centre reste à l'encoche matérielle.
///
/// Comme `DeviceStatusPillView`, pas de fond : la silhouette de l'encoche élargie est le fond.
final class AgentEventPillView: NSView {

    /// Largeur de chaque aile, de part et d'autre de l'encoche.
    static let wingWidth: CGFloat = 150

    private let iconView = NSImageView()
    private let projectLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")

    private let inset: CGFloat = 16
    private let iconSize: CGFloat = 18
    private var notchWidth: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        projectLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        projectLabel.textColor = .white
        projectLabel.lineBreakMode = .byTruncatingTail
        addSubview(projectLabel)

        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        statusLabel.alignment = .right
        addSubview(statusLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ event: AgentEvent, notchWidth: CGFloat) {
        let tint: NSColor = event.kind == .needsInput ? .systemOrange : .systemGreen
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        iconView.image = NSImage(systemSymbolName: event.kind.symbolName, accessibilityDescription: event.kind.statusText)?
            .withSymbolConfiguration(configuration)
        iconView.contentTintColor = tint
        projectLabel.stringValue = event.project
        statusLabel.stringValue = event.kind.statusText
        statusLabel.textColor = tint
        self.notchWidth = notchWidth
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let wing = Self.wingWidth
        iconView.frame = NSRect(x: inset, y: (bounds.height - iconSize) / 2, width: iconSize, height: iconSize)

        let labelHeight = projectLabel.intrinsicContentSize.height
        let labelX = inset + iconSize + 7
        projectLabel.frame = NSRect(
            x: labelX, y: (bounds.height - labelHeight) / 2, width: max(0, wing - labelX - 6), height: labelHeight)

        let rightX = wing + notchWidth + 6
        statusLabel.frame = NSRect(
            x: rightX, y: (bounds.height - labelHeight) / 2,
            width: max(0, bounds.width - rightX - inset), height: labelHeight)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

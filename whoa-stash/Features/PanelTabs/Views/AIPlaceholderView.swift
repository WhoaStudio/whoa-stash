import AppKit

/// Onglet AI : rien à montrer encore, seulement l'écriteau qui dit que la place est réservée.
/// Volontairement sans logique — il n'y a pas de fournisseur derrière lui à ce stade.
final class AIPlaceholderView: NSView {

    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "Coming soon")

    private let iconSize: CGFloat = 22

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        let configuration = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
        iconView.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.alignment = .center
        label.font = .systemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .regular)
        addSubview(label)

        applyPalette()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPalette()
    }

    private func applyPalette() {
        let palette = OverlayPalette.resolved(for: effectiveAppearance)
        iconView.contentTintColor = palette.tabInactiveContent
        label.textColor = palette.tabInactiveContent
    }

    override func layout() {
        super.layout()

        // Le couple icône + intitulé est centré comme un bloc, pas chacun de son côté.
        let labelHeight = label.intrinsicContentSize.height
        let gap: CGFloat = 8
        let blockHeight = iconSize + gap + labelHeight
        let top = bounds.midY + blockHeight / 2

        iconView.frame = NSRect(
            x: bounds.midX - iconSize / 2,
            y: top - iconSize,
            width: iconSize,
            height: iconSize
        )
        label.frame = NSRect(
            x: bounds.minX,
            y: iconView.frame.minY - gap - labelHeight,
            width: bounds.width,
            height: labelHeight
        )
    }
}

import AppKit

/// Onglet Tray : une zone de dépôt qui retient les fichiers qu'on y lâche, avec leur icône et
/// leur nom.
///
/// Les fichiers ne sont que **référencés** — rien n'est copié ni déplacé sur le disque, et la
/// liste ne survit pas au redémarrage de l'app. C'est la version minimale : de quoi poser des
/// fichiers le temps d'une session, pas encore un bac persistant.
final class FileTrayView: NSView {

    private let emptyLabel = NSTextField(labelWithString: "Drop files here")
    private let dropHighlightLayer = CAShapeLayer()
    private var rows: [FileTrayRowView] = []

    /// Fichiers retenus, dans l'ordre où ils ont été déposés.
    private var urls: [URL] = []

    /// Au-delà, les derniers déposés chassent les premiers : la zone n'a de place que pour
    /// quelques lignes et ne défile pas encore.
    private let maximumVisibleRows = 4

    private let rowHeight: CGFloat = 26
    private let rowSpacing: CGFloat = 4

    private var isDropTarget = false

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
        // Liseré en tirets : il dit « on peut déposer ici » sans peser autant qu'un cadre plein,
        // et c'est lui qui s'allume quand un glisser survole la zone.
        dropHighlightLayer.fillColor = nil
        dropHighlightLayer.lineWidth = 1
        dropHighlightLayer.lineDashPattern = [4, 4]
        layer?.addSublayer(dropHighlightLayer)

        emptyLabel.isBezeled = false
        emptyLabel.drawsBackground = false
        emptyLabel.isEditable = false
        emptyLabel.isSelectable = false
        emptyLabel.alignment = .center
        emptyLabel.font = .systemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .regular)
        addSubview(emptyLabel)

        registerForDraggedTypes([.fileURL])
        applyPalette()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPalette()
    }

    private func applyPalette() {
        let palette = OverlayPalette.resolved(for: effectiveAppearance)
        emptyLabel.textColor = palette.tabInactiveContent
        // Le liseré se renforce pendant le survol d'un glisser, sans changer de teinte.
        dropHighlightLayer.strokeColor = isDropTarget ? palette.tabActiveContent.cgColor : palette.strokeColor
        rows.forEach { $0.applyPalette(palette) }
    }

    // MARK: - Dépôt

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: readingOptions) else {
            return []
        }
        isDropTarget = true
        applyPalette()
        return .copy
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        isDropTarget = false
        applyPalette()
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        isDropTarget = false
        applyPalette()

        guard
            let dropped = sender.draggingPasteboard.readObjects(
                forClasses: [NSURL.self],
                options: readingOptions
            ) as? [URL],
            !dropped.isEmpty
        else { return false }

        // Un même fichier déposé deux fois ne fait pas deux lignes : il remonte simplement en fin
        // de liste, là où l'utilisateur vient de le poser.
        urls.removeAll { dropped.contains($0) }
        urls.append(contentsOf: dropped)
        if urls.count > maximumVisibleRows {
            urls.removeFirst(urls.count - maximumVisibleRows)
        }

        rebuildRows()
        return true
    }

    private var readingOptions: [NSPasteboard.ReadingOptionKey: Any] {
        [.urlReadingFileURLsOnly: true]
    }

    private func rebuildRows() {
        rows.forEach { $0.removeFromSuperview() }
        rows = urls.map(FileTrayRowView.init(url:))
        rows.forEach(addSubview)
        emptyLabel.isHidden = !urls.isEmpty
        applyPalette()
        needsLayout = true
    }

    override func layout() {
        super.layout()

        dropHighlightLayer.frame = bounds
        dropHighlightLayer.path = CGPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            cornerWidth: 10,
            cornerHeight: 10,
            transform: nil
        )

        let labelHeight = emptyLabel.intrinsicContentSize.height
        emptyLabel.frame = NSRect(
            x: bounds.minX,
            y: bounds.midY - labelHeight / 2,
            width: bounds.width,
            height: labelHeight
        )

        // Empilées depuis le haut, le dernier déposé en bas de la pile visible.
        let inset: CGFloat = 8
        for (position, row) in rows.enumerated() {
            let top = bounds.maxY - inset - CGFloat(position) * (rowHeight + rowSpacing)
            row.frame = NSRect(
                x: bounds.minX + inset,
                y: top - rowHeight,
                width: bounds.width - 2 * inset,
                height: rowHeight
            )
        }
    }
}

// MARK: - Une ligne

/// Une ligne du bac : l'icône que le Finder donne au fichier, et son nom.
private final class FileTrayRowView: NSView {

    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    private let iconSize: CGFloat = 16

    init(url: URL) {
        super.init(frame: .zero)
        wantsLayer = true

        // L'icône vient du Finder : un fichier déposé garde donc l'apparence qu'il a sur le
        // bureau, type et vignette compris.
        iconView.image = NSWorkspace.shared.icon(forFile: url.path)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        label.stringValue = url.lastPathComponent
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.lineBreakMode = .byTruncatingMiddle
        label.font = .systemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .regular)
        addSubview(label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyPalette(_ palette: OverlayPalette) {
        label.textColor = palette.tabActiveContent
    }

    override func layout() {
        super.layout()

        iconView.frame = NSRect(
            x: bounds.minX,
            y: bounds.midY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )

        let labelHeight = label.intrinsicContentSize.height
        let x = iconView.frame.maxX + 8
        label.frame = NSRect(
            x: x,
            y: bounds.midY - labelHeight / 2,
            width: max(0, bounds.maxX - x),
            height: labelHeight
        )
    }
}

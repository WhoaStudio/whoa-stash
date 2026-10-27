import AppKit

/// Onglet Tray : une zone de dépôt qui retient les fichiers qu'on y lâche, avec leur icône et
/// leur nom.
///
/// La vue n'est qu'une lecture de `FileShelfStore` — c'est lui qui retient les fichiers, et donc
/// le bac survit au repli du panneau, au changement d'onglet et au relancement de l'app. Les
/// fichiers ne sont que **référencés** : rien n'est copié ni déplacé sur le disque.
///
/// La vue **ne s'enregistre pas** comme cible de dépôt : c'est le panneau tout entier qui la
/// porte (`NotchPanelContentView`), parce qu'un fichier se lâche sur l'encoche — en haut, là où
/// la silhouette repliée se voit — et pas dans le rectangle du bac, qui est tout en bas du
/// panneau déplié. Il n'y a donc toujours qu'une cible, simplement plus large que le bac : le
/// panneau lui confie ce qu'il reçoit (`canAccept(_:)` / `accept(_:)`).
///
/// Un fichier en ressort comme de n'importe quel bac du système : on le glisse vers le Finder ou
/// une autre app, et il ne quitte le bac qu'une fois le dépôt abouti (voir `FileTrayRowView`).
final class FileTrayView: NSView {

    private let emptyLabel = NSTextField(labelWithString: "Drop files here")
    private let dropHighlightLayer = CAShapeLayer()
    private var rows: [FileTrayRowView] = []

    private let store: FileShelfStore
    /// `nonisolated(unsafe)` pour pouvoir être retiré depuis `deinit`, qui n'est pas isolé sur
    /// le main actor : le jeton n'est touché qu'à l'installation et à la destruction de la vue,
    /// toutes deux sur le main actor de fait.
    nonisolated(unsafe) private var storeObserver: NSObjectProtocol?

    private let rowHeight: CGFloat = 26
    private let rowSpacing: CGFloat = 4

    private var isDropTarget = false

    init(frame frameRect: NSRect = .zero, store: FileShelfStore = .shared) {
        self.store = store
        super.init(frame: frameRect)
        wantsLayer = true
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let storeObserver {
            NotificationCenter.default.removeObserver(storeObserver)
        }
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

        // Il y a une vue par écran, et elles vont et viennent avec les fenêtres : chacune suit
        // le bac partagé plutôt que d'être tenue par lui.
        storeObserver = NotificationCenter.default.addObserver(
            forName: FileShelfStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.rebuildRows() }
        }

        rebuildRows()
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

    /// Le glisser est-il de ceux que le bac retient ? Un glisser venu d'une ligne du bac
    /// lui-même ne l'est pas : relâcher là d'où l'on vient doit se lire comme un glisser annulé,
    /// qui laisse le fichier en place, et non comme un dépôt abouti qui l'en retirerait.
    func canAccept(_ sender: any NSDraggingInfo) -> Bool {
        guard !(sender.draggingSource is FileTrayRowView) else { return false }
        return sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: readingOptions)
    }

    /// Range dans le bac ce que le panneau vient de recevoir.
    func accept(_ sender: any NSDraggingInfo) -> Bool {
        guard
            canAccept(sender),
            let dropped = sender.draggingPasteboard.readObjects(
                forClasses: [NSURL.self],
                options: readingOptions
            ) as? [URL],
            !dropped.isEmpty
        else { return false }

        store.add(dropped)
        return true
    }

    /// Allume le liseré pendant qu'un glisser survole le panneau. C'est lui qui dit où le
    /// fichier va tomber, alors que la cible, elle, est tout le panneau.
    func setDropHighlighted(_ highlighted: Bool) {
        guard highlighted != isDropTarget else { return }
        isDropTarget = highlighted
        applyPalette()
    }

    private var readingOptions: [NSPasteboard.ReadingOptionKey: Any] {
        [.urlReadingFileURLsOnly: true]
    }

    private func rebuildRows() {
        rows.forEach { $0.removeFromSuperview() }
        rows = store.urls.map { FileTrayRowView(url: $0, store: store) }
        rows.forEach(addSubview)
        emptyLabel.isHidden = !store.isEmpty
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
///
/// C'est aussi la source du glisser vers l'extérieur. Le fichier ne quitte le bac que si le
/// dépôt a abouti — `draggingSession(_:endedAt:operation:)` reçoit alors une opération non
/// vide ; un glisser annulé, ou relâché dans le vide, en reçoit une vide et laisse la ligne en
/// place.
private final class FileTrayRowView: NSView, NSDraggingSource {

    private let url: URL
    private let store: FileShelfStore
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    private let iconSize: CGFloat = 16

    /// Distance à parcourir avant qu'un `mouseDragged` devienne un glisser : sans ce seuil, le
    /// moindre tremblement au clic en lancerait un.
    private let dragThreshold: CGFloat = 3
    private var mouseDownLocation: NSPoint?

    init(url: URL, store: FileShelfStore) {
        self.url = url
        self.store = store
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

    // MARK: - Glisser vers l'extérieur

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let origin = mouseDownLocation else { return }
        let location = convert(event.locationInWindow, from: nil)
        guard hypot(location.x - origin.x, location.y - origin.y) >= dragThreshold else { return }
        mouseDownLocation = nil
        beginDrag(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownLocation = nil
    }

    private func beginDrag(with event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        // La vignette sous le curseur est celle de la ligne — l'icône du Finder à sa taille
        // d'affichage —, pas la ligne entière : c'est le fichier qu'on déplace.
        let image = iconView.image
        item.setDraggingFrame(iconView.frame, contents: image)

        // Le panneau se replie dès que le curseur le quitte : il faut geler ce suivi le temps du
        // glisser, sans quoi le bac se refermerait sous la main qui en sort un fichier.
        store.isDraggingOut = true
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        switch context {
        // Jamais `.move` : le Finder le prendrait au mot et déplacerait le fichier sur le
        // disque. Le bac ne fait que référencer, il ne range pas à la place de l'utilisateur.
        case .outsideApplication: .copy
        // Dans l'app, il n'y a rien où déposer : relâcher sur le bac doit se lire comme un
        // glisser annulé.
        default: []
        }
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        store.isDraggingOut = false
        // Une opération vide, c'est un glisser annulé ou relâché dans le vide : le fichier reste.
        guard !operation.isEmpty else { return }
        store.remove(url)
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

import AppKit
import OSLog
import QuickLookThumbnailing

/// Onglet Tray : une zone de dépôt qui retient les fichiers qu'on y lâche, rangés en grille de
/// vignettes — l'aperçu du fichier, son nom dessous — comme dans la vue en icônes du Finder.
///
/// La vue n'est qu'une lecture de `FileShelfStore` — c'est lui qui retient les fichiers, et donc
/// le bac survit au repli du panneau, au changement d'onglet et au relancement de l'app. Les
/// fichiers sont déplacés dans le dossier du bac, puis référencés par des signets.
///
/// La vue **ne s'enregistre pas** comme cible de dépôt : c'est le panneau tout entier qui la
/// porte (`NotchPanelContentView`), parce qu'un fichier se lâche sur l'encoche — en haut, là où
/// la silhouette repliée se voit — et pas dans le rectangle du bac, qui est tout en bas du
/// panneau déplié. Il n'y a donc toujours qu'une cible, simplement plus large que le bac : le
/// panneau lui confie ce qu'il reçoit (`canAccept(_:)` / `accept(_:)`).
///
/// Un fichier en ressort comme de n'importe quel bac du système : on le glisse vers le Finder ou
/// une autre app, et il ne quitte le bac qu'une fois le dépôt abouti (voir `FileTrayItemView`).
final class FileTrayView: NSView {

    private let emptyLabel = NSTextField(labelWithString: "Drop files here")
    private let dropHighlightLayer = CAShapeLayer()
    private var items: [FileTrayItemView] = []

    private let store: FileShelfStore
    /// `nonisolated(unsafe)` pour pouvoir être retiré depuis `deinit`, qui n'est pas isolé sur
    /// le main actor : le jeton n'est touché qu'à l'installation et à la destruction de la vue,
    /// toutes deux sur le main actor de fait.
    nonisolated(unsafe) private var storeObserver: NSObjectProtocol?

    private let tileSpacing: CGFloat = 8

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
        let dropColor = NSColor.systemBlue
        emptyLabel.textColor = dropColor
        // Le liseré se renforce pendant le survol d'un glisser, sans changer de teinte.
        dropHighlightLayer.strokeColor = dropColor
            .withAlphaComponent(isDropTarget ? 1 : 0.72)
            .cgColor
        items.forEach { $0.applyPalette(palette) }
    }

    // MARK: - Dépôt

    /// Le glisser est-il de ceux que le bac retient ? Un glisser venu d'une ligne du bac
    /// lui-même ne l'est pas : relâcher là d'où l'on vient doit se lire comme un glisser annulé,
    /// qui laisse le fichier en place, et non comme un dépôt abouti qui l'en retirerait.
    func canAccept(_ sender: any NSDraggingInfo) -> Bool {
        guard !(sender.draggingSource is FileTrayItemView) else { return false }
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

        return !store.add(dropped).isEmpty
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
        items.forEach { $0.removeFromSuperview() }
        items = store.urls.map { FileTrayItemView(url: $0, store: store) }
        items.forEach(addSubview)
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

        // Grille centrée, rangée par rangée : le nombre de colonnes suit la largeur, et une
        // rangée incomplète se centre d'elle-même plutôt que de coller à gauche.
        let tile = FileTrayItemView.tileSize
        let inset: CGFloat = 8
        let columns = max(1, Int((bounds.width - 2 * inset + tileSpacing) / (tile.width + tileSpacing)))
        let rowCount = (items.count + columns - 1) / columns
        let gridHeight = CGFloat(rowCount) * tile.height + CGFloat(max(0, rowCount - 1)) * tileSpacing
        let gridTop = bounds.midY + gridHeight / 2

        for (position, item) in items.enumerated() {
            let row = position / columns
            let column = position % columns
            let inRow = min(columns, items.count - row * columns)
            let rowWidth = CGFloat(inRow) * tile.width + CGFloat(inRow - 1) * tileSpacing
            item.frame = NSRect(
                x: bounds.midX - rowWidth / 2 + CGFloat(column) * (tile.width + tileSpacing),
                y: gridTop - CGFloat(row + 1) * tile.height - CGFloat(row) * tileSpacing,
                width: tile.width,
                height: tile.height
            )
        }
    }
}

// MARK: - Une vignette

/// Une vignette du bac : l'aperçu du fichier, et son nom dessous.
///
/// L'aperçu part de l'icône que le Finder donne au fichier — l'icône de dossier, ou celle du
/// type avec le badge de l'app par défaut —, puis passe à la vignette de contenu de QuickLook
/// (texte, JSON, image…) dès qu'elle est prête. Un fichier sans vignette garde son icône.
///
/// C'est aussi la source du glisser vers l'extérieur. Le fichier ne quitte le bac que si le
/// dépôt a abouti — `draggingSession(_:endedAt:operation:)` reçoit alors une opération non
/// vide ; un glisser annulé, ou relâché dans le vide, en reçoit une vide et laisse la vignette en
/// place.
private final class FileTrayItemView: NSView, NSDraggingSource {

    static let tileSize = NSSize(width: 104, height: 110)

    private let url: URL
    private let store: FileShelfStore
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private var thumbnailTask: Task<Void, Never>?

    private let previewSize: CGFloat = 64
    private let labelGap: CGFloat = 6
    private let maxLabelLines = 2
    private let labelFont = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .regular)

    /// Distance à parcourir avant qu'un `mouseDragged` devienne un glisser : sans ce seuil, le
    /// moindre tremblement au clic en lancerait un.
    private let dragThreshold: CGFloat = 3
    private var mouseDownLocation: NSPoint?

    init(url: URL, store: FileShelfStore) {
        self.url = url
        self.store = store
        super.init(frame: .zero)
        wantsLayer = true

        iconView.image = NSWorkspace.shared.icon(forFile: url.path)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.alignment = .center
        label.font = labelFont
        label.lineBreakMode = .byCharWrapping
        label.maximumNumberOfLines = maxLabelLines
        label.stringValue = truncatedName(url.lastPathComponent)
        addSubview(label)

        loadThumbnail()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyPalette(_ palette: OverlayPalette) {
        label.textColor = palette.tabActiveContent
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        // La vignette retirée du bac n'a plus besoin de son aperçu.
        if superview == nil { thumbnailTask?.cancel() }
    }

    // MARK: - Aperçu

    private func loadThumbnail() {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: previewSize, height: previewSize),
            scale: scale,
            representationTypes: .thumbnail
        )
        thumbnailTask = Task { [weak self] in
            do {
                let representation = try await QLThumbnailGenerator.shared
                    .generateBestRepresentation(for: request)
                guard !Task.isCancelled else { return }
                self?.iconView.image = representation.nsImage
            } catch {
                // Pas de vignette de contenu pour ce type : l'icône du Finder reste.
                Log.sidePanel.debug("Pas de vignette QuickLook : \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    // MARK: - Nom

    /// Coupe le nom **au milieu** quand il ne tient pas sur `maxLabelLines` lignes, comme le
    /// Finder : on garde le début et la fin, donc l'extension. `NSTextField` ne sait couper qu'en
    /// fin de dernière ligne sur plusieurs lignes, d'où la mesure à la main.
    private func truncatedName(_ name: String) -> String {
        let width = Self.tileSize.width
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byCharWrapping
        style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [.font: labelFont, .paragraphStyle: style]
        let lineHeight = ceil(labelFont.ascender - labelFont.descender + labelFont.leading)

        func fits(_ text: String) -> Bool {
            let rect = (text as NSString).boundingRect(
                with: NSSize(width: width, height: .greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin,
                attributes: attributes
            )
            return ceil(rect.height) <= lineHeight * CGFloat(maxLabelLines)
        }

        guard !fits(name) else { return name }

        let characters = Array(name)
        let tailLength = min(characters.count / 2, (url.pathExtension.count + 1) + 3)
        let tail = String(characters.suffix(tailLength))
        var low = 0
        var high = characters.count - tailLength
        while low < high {
            let middle = (low + high + 1) / 2
            if fits(String(characters.prefix(middle)) + "…" + tail) {
                low = middle
            } else {
                high = middle - 1
            }
        }
        return String(characters.prefix(low)) + "…" + tail
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
        // L'image sous le curseur est l'aperçu de la vignette, pas la vignette entière : c'est
        // le fichier qu'on déplace.
        item.setDraggingFrame(iconView.frame, contents: iconView.image)

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
        // Le bac possède réellement les fichiers qu'il contient : Finder doit donc déplacer
        // le fichier hors de son dossier géré, plutôt que d'en créer une copie.
        case .outsideApplication: .move
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
            x: bounds.midX - previewSize / 2,
            y: bounds.maxY - previewSize,
            width: previewSize,
            height: previewSize
        )

        let labelTop = iconView.frame.minY - labelGap
        label.frame = NSRect(x: 0, y: 0, width: bounds.width, height: max(0, labelTop))
        // Le texte se cale en haut de la zone, juste sous l'aperçu, quelle que soit sa hauteur.
        let textHeight = min(label.sizeThatFits(NSSize(width: bounds.width, height: .greatestFiniteMagnitude)).height, labelTop)
        label.frame = NSRect(x: 0, y: labelTop - textHeight, width: bounds.width, height: textHeight)
    }
}

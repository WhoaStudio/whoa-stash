import AppKit

/// Lecteur de l'onglet Global, déplié : pochette portant l'icône de l'application qui joue, titre
/// et artiste avec le visualiseur à leur droite, puis la progression encadrée du temps écoulé et
/// du temps restant, et enfin précédent / lecture-pause / suivant avec le volume du système.
///
/// Quand une source sait donner la suite (Apple Musique, Spotify), la colonne « Playing Next »
/// s'ouvre à droite, séparée par un filet, et le lecteur se resserre sur la gauche ; sinon il
/// occupe toute la largeur.
final class NowPlayingRowView: NSView {

    var onCommand: ((NowPlayingCommand) -> Void)?

    private let artworkView = ArtworkView()
    private let titleLabel = NowPlayingRowView.label(size: 17, weight: .semibold, color: .white)
    private let artistLabel = NowPlayingRowView.label(size: 14, weight: .regular, color: .white.withAlphaComponent(0.5))
    private let visualizer = AudioVisualizerView()
    private let elapsedLabel = NowPlayingRowView.label(size: 12, weight: .regular, color: .white.withAlphaComponent(0.5))
    private let remainingLabel = NowPlayingRowView.label(size: 12, weight: .regular, color: .white.withAlphaComponent(0.5))
    private let progress = NowPlayingSliderView(isInteractive: false)
    private let volumeSlider = NowPlayingSliderView(isInteractive: true)
    private let volumeIcon = NSImageView()
    private let previousButton = NowPlayingControlButton(symbol: "backward.fill", size: 18)
    private let playPauseButton = NowPlayingControlButton(symbol: "pause.fill", size: 24)
    private let nextButton = NowPlayingControlButton(symbol: "forward.fill", size: 18)

    private let queueHeader = NowPlayingRowView.label(size: 13, weight: .semibold, color: .white.withAlphaComponent(0.5))
    private let queueDivider = NSBox()
    private let queueViews = (0..<3).map { _ in QueueItemView() }

    private var state: NowPlayingState?
    private var tickTimer: Timer?
    private var queue: [QueueItem] = []

    /// Part de la largeur gardée par le lecteur quand la colonne de droite est ouverte.
    private let playerShare: CGFloat = 0.58
    private let queueGap: CGFloat = 20

    private let controlsHeight: CGFloat = 32
    private let progressHeight: CGFloat = 14
    private let rowGap: CGFloat = 4
    private let buttonPitch: CGFloat = 52
    private let volumeWidth: CGFloat = 150
    private let timeWidth: CGFloat = 40
    /// Marge interne d'un `NSTextField` de chaque côté : sans elle compensée, le texte ne tombe
    /// pas sur les bords de la pochette et du curseur de volume.
    private let labelPadding: CGFloat = 2

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        artworkView.badgeScale = 0.36
        artworkView.badgeInset = 4
        addSubview(artworkView)

        titleLabel.lineBreakMode = .byTruncatingTail
        artistLabel.lineBreakMode = .byTruncatingTail
        for label in [elapsedLabel, remainingLabel] {
            label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        }
        remainingLabel.alignment = .right
        for view in [titleLabel, artistLabel, visualizer, elapsedLabel, remainingLabel, progress] as [NSView] {
            addSubview(view)
        }

        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        volumeIcon.image = NSImage(systemSymbolName: "speaker.fill", accessibilityDescription: "Volume")?
            .withSymbolConfiguration(configuration)
        volumeIcon.contentTintColor = .white.withAlphaComponent(0.5)
        addSubview(volumeIcon)
        volumeSlider.setAccessibilityLabel("Volume")
        volumeSlider.onChange = { value in SystemVolumeService.shared.setVolume(Float(value)) }
        addSubview(volumeSlider)

        previousButton.onClick = { [weak self] in self?.onCommand?(.previousTrack) }
        playPauseButton.onClick = { [weak self] in self?.onCommand?(.togglePlayPause) }
        nextButton.onClick = { [weak self] in self?.onCommand?(.nextTrack) }
        [previousButton, playPauseButton, nextButton].forEach(addSubview)

        queueHeader.stringValue = "Playing Next"
        queueDivider.boxType = .custom
        queueDivider.borderWidth = 0
        queueDivider.fillColor = .white.withAlphaComponent(0.15)
        for view in [queueHeader, queueDivider] as [NSView] { addSubview(view) }
        queueViews.forEach(addSubview)
        apply(queue: [])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func label(size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        return label
    }

    func apply(_ state: NowPlayingState?) {
        self.state = state
        guard let state else {
            tickTimer?.invalidate()
            tickTimer = nil
            titleLabel.stringValue = "Nothing playing"
            artistLabel.stringValue = ""
            artworkView.setArtwork(nil)
            artworkView.clearSource()
            visualizer.setAnimating(false)
            playPauseButton.setSymbol("play.fill")
            updateProgress()
            needsLayout = true
            return
        }
        titleLabel.stringValue = state.title
        artistLabel.stringValue = [state.artist, state.album].filter { !$0.isEmpty }.joined(separator: " - ")
        artworkView.setArtwork(state.artwork)
        artworkView.setSource(bundleIdentifier: state.bundleIdentifier)
        visualizer.setAnimating(state.isPlaying)
        playPauseButton.setSymbol(state.isPlaying ? "pause.fill" : "play.fill")
        updateProgress()

        // La position n'est renvoyée qu'aux changements : on l'avance ici, tant que ça joue.
        if state.isPlaying, tickTimer == nil {
            let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateProgress() }
            }
            timer.tolerance = 0.2
            RunLoop.main.add(timer, forMode: .common)
            tickTimer = timer
        } else if !state.isPlaying {
            tickTimer?.invalidate()
            tickTimer = nil
        }
        needsLayout = true
    }

    /// Les prochains titres ; vide referme la colonne.
    func apply(queue newQueue: [QueueItem]) {
        queue = newQueue
        let visible = !newQueue.isEmpty
        queueHeader.isHidden = !visible
        queueDivider.isHidden = !visible
        for (index, view) in queueViews.enumerated() {
            view.isHidden = index >= newQueue.count
            if index < newQueue.count { view.apply(newQueue[index]) }
        }
        needsLayout = true
    }

    /// Relit le volume du système — à chaque dépliage, il a pu changer ailleurs.
    func refreshVolume() {
        volumeSlider.setValue(Double(SystemVolumeService.shared.getVolume()))
    }

    private func updateProgress() {
        guard let state, let duration = state.duration, duration > 0, let position = state.position() else {
            progress.setValue(0)
            elapsedLabel.stringValue = ""
            remainingLabel.stringValue = ""
            return
        }
        progress.setValue(position / duration)
        elapsedLabel.stringValue = Self.clock(position)
        remainingLabel.stringValue = "-" + Self.clock(duration - position)
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    override func layout() {
        super.layout()
        // De bas en haut : commandes, progression, puis la pochette avec titre et artiste.
        let controlsY: CGFloat = 0
        let progressY = controlsHeight + rowGap
        let headerY = progressY + progressHeight + rowGap
        let artSize = max(0, bounds.height - headerY)
        artworkView.frame = NSRect(x: 0, y: headerY, width: artSize, height: artSize)

        // Le lecteur tient dans `playerWidth` ; la colonne de droite prend le reste.
        let hasQueue = !queue.isEmpty
        let playerWidth = hasQueue ? (bounds.width * playerShare).rounded() : bounds.width
        layoutQueueColumn(playerWidth: playerWidth, headerY: headerY, artSize: artSize)

        // Titre et artiste forment un bloc centré sur la pochette ; sans artiste, le titre seul
        // prend le milieu.
        let textX = artSize + 14
        let titleHeight: CGFloat = 22
        let artistHeight: CGFloat = 20
        let hasArtist = !artistLabel.stringValue.isEmpty
        let blockHeight = hasArtist ? titleHeight + artistHeight : titleHeight
        let blockBottom = headerY + (artSize - blockHeight) / 2
        let titleY = hasArtist ? blockBottom + artistHeight : blockBottom

        let vizSize = visualizer.intrinsicContentSize
        // Le visualiseur est centré sur la ligne du titre et colle au bord droit.
        visualizer.frame = NSRect(
            x: playerWidth - vizSize.width, y: titleY + (titleHeight - vizSize.height) / 2,
            width: vizSize.width, height: vizSize.height)
        let textWidth = max(0, visualizer.frame.minX - 10 - textX)
        titleLabel.frame = NSRect(x: textX - labelPadding, y: titleY, width: textWidth, height: titleHeight)
        artistLabel.frame = NSRect(
            x: textX - labelPadding, y: blockBottom, width: playerWidth - textX, height: artistHeight)

        // Temps écoulé et restant sont calés sur les bords de la pochette et du volume.
        elapsedLabel.frame = NSRect(
            x: -labelPadding, y: progressY - 1, width: timeWidth, height: progressHeight + 2)
        remainingLabel.frame = NSRect(
            x: playerWidth - timeWidth + labelPadding, y: progressY - 1, width: timeWidth,
            height: progressHeight + 2)
        progress.frame = NSRect(
            x: timeWidth + 6 - labelPadding, y: progressY,
            width: max(0, playerWidth - 2 * (timeWidth + 6 - labelPadding)), height: progressHeight)

        // Le volume colle au bord droit ; les trois commandes se centrent dans la place restante.
        let controlsMidY = controlsY + (controlsHeight - 16) / 2
        let volume = hasQueue ? volumeWidth * 0.6 : volumeWidth
        volumeSlider.frame = NSRect(x: playerWidth - volume, y: controlsMidY, width: volume, height: 16)
        volumeIcon.frame = NSRect(x: volumeSlider.frame.minX - 26, y: controlsMidY, width: 18, height: 16)

        let buttons = [previousButton, playPauseButton, nextButton]
        let groupWidth = buttonPitch * CGFloat(buttons.count)
        let groupX = max(0, (volumeIcon.frame.minX - 12 - groupWidth) / 2)
        for (index, button) in buttons.enumerated() {
            button.frame = NSRect(
                x: groupX + CGFloat(index) * buttonPitch, y: controlsY, width: buttonPitch, height: controlsHeight)
        }
    }
}

extension NowPlayingRowView {

    /// Filet, titre de colonne et trois lignes, alignés sur le haut de la pochette.
    fileprivate func layoutQueueColumn(playerWidth: CGFloat, headerY: CGFloat, artSize: CGFloat) {
        let columnX = playerWidth + queueGap
        let columnWidth = max(0, bounds.width - columnX)
        let top = headerY + artSize

        queueDivider.frame = NSRect(x: playerWidth + queueGap / 2, y: 4, width: 1, height: max(0, bounds.height - 8))
        queueHeader.frame = NSRect(x: columnX - 2, y: top - 18, width: columnWidth, height: 18)

        let rowHeight: CGFloat = 32
        let firstRowTop = top - 24
        for (index, view) in queueViews.enumerated() {
            view.frame = NSRect(
                x: columnX, y: firstRowTop - CGFloat(index + 1) * rowHeight - CGFloat(index) * 2,
                width: columnWidth, height: rowHeight)
        }
    }
}

/// Une ligne de la file : petite pochette, titre, artiste.
final class QueueItemView: NSView {

    private let artworkView = ArtworkView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let artistLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        artworkView.showsSourceBadge = false
        artworkView.cornerRadius = 5
        addSubview(artworkView)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .white
        artistLabel.font = .systemFont(ofSize: 12)
        artistLabel.textColor = .white.withAlphaComponent(0.5)
        for label in [titleLabel, artistLabel] {
            label.lineBreakMode = .byTruncatingTail
            addSubview(label)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ item: QueueItem) {
        titleLabel.stringValue = item.title
        artistLabel.stringValue = item.artist
        artworkView.setArtwork(item.artwork)
    }

    override func layout() {
        super.layout()
        let art = bounds.height - 4
        artworkView.frame = NSRect(x: 0, y: 2, width: art, height: art)
        let textX = art + 10
        let width = max(0, bounds.width - textX)
        titleLabel.frame = NSRect(x: textX - 2, y: bounds.midY, width: width + 2, height: 16)
        artistLabel.frame = NSRect(x: textX - 2, y: bounds.midY - 15, width: width + 2, height: 15)
    }
}

/// Bouton-glyphe qui s'éclaircit au survol, sur le modèle de `NotchGearButtonView`.
final class NowPlayingControlButton: NSView {

    var onClick: (() -> Void)?

    private let iconView = NSImageView()
    private let pointSize: CGFloat
    private var isHovered = false {
        didSet { iconView.contentTintColor = .white.withAlphaComponent(isHovered ? 1 : 0.9) }
    }
    private var trackingArea: NSTrackingArea?

    init(symbol: String, size: CGFloat) {
        pointSize = size
        super.init(frame: .zero)
        iconView.imageScaling = .scaleProportionallyDown
        iconView.contentTintColor = .white.withAlphaComponent(0.9)
        addSubview(iconView)
        setSymbol(symbol)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSymbol(_ name: String) {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
        iconView.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    }

    override func layout() {
        super.layout()
        iconView.frame = bounds
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

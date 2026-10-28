import AppKit

/// Lecteur de l'onglet Global, déplié : pochette portant l'icône de l'application qui joue, titre
/// et artiste avec le visualiseur à leur droite, puis la progression encadrée du temps écoulé et
/// du temps restant, et enfin précédent / lecture-pause / suivant avec le volume du système.
///
/// Pas de file « Playing Next » : la source système ne la donne pas (voir `NowPlayingState`).
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

    private var state: NowPlayingState?
    private var tickTimer: Timer?

    private let controlsHeight: CGFloat = 32
    private let progressHeight: CGFloat = 14
    private let rowGap: CGFloat = 4
    private let buttonPitch: CGFloat = 52
    private let volumeWidth: CGFloat = 150
    private let timeWidth: CGFloat = 40

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

        let textX = artSize + 14
        let vizSize = visualizer.intrinsicContentSize
        visualizer.frame = NSRect(
            x: bounds.maxX - vizSize.width, y: headerY + artSize / 2 + 8 + (20 - vizSize.height) / 2,
            width: vizSize.width, height: vizSize.height)
        let textWidth = max(0, visualizer.frame.minX - 10 - textX)
        titleLabel.frame = NSRect(x: textX, y: headerY + artSize / 2 + 2, width: textWidth, height: 22)
        artistLabel.frame = NSRect(x: textX, y: headerY + artSize / 2 - 22, width: bounds.maxX - textX, height: 20)

        elapsedLabel.frame = NSRect(x: 0, y: progressY - 1, width: timeWidth, height: progressHeight + 2)
        remainingLabel.frame = NSRect(
            x: bounds.maxX - timeWidth, y: progressY - 1, width: timeWidth, height: progressHeight + 2)
        progress.frame = NSRect(
            x: timeWidth + 6, y: progressY, width: max(0, bounds.width - 2 * (timeWidth + 6)), height: progressHeight)

        let buttons = [previousButton, playPauseButton, nextButton]
        let groupWidth = buttonPitch * CGFloat(buttons.count)
        let groupX = (bounds.width - groupWidth) / 2 - 40
        for (index, button) in buttons.enumerated() {
            button.frame = NSRect(
                x: groupX + CGFloat(index) * buttonPitch, y: controlsY, width: buttonPitch, height: controlsHeight)
        }

        volumeSlider.frame = NSRect(
            x: bounds.maxX - volumeWidth, y: controlsY + (controlsHeight - 16) / 2, width: volumeWidth, height: 16)
        volumeIcon.frame = NSRect(
            x: volumeSlider.frame.minX - 26, y: controlsY + (controlsHeight - 16) / 2, width: 18, height: 16)
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

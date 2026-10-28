import AppKit

/// Ligne « en lecture » de l'onglet Global, dépliée : pochette, titre et artiste, puis
/// précédent / lecture-pause / suivant. Les ailes de l'encoche sont trop étroites pour porter
/// des boutons — c'est ici qu'on pilote.
final class NowPlayingRowView: NSView {

    var onCommand: ((NowPlayingCommand) -> Void)?

    private let artworkView = ArtworkView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let artistLabel = NSTextField(labelWithString: "")
    private let visualizer = AudioVisualizerView()
    private let previousButton = NowPlayingControlButton(symbol: "backward.fill", size: 14)
    private let playPauseButton = NowPlayingControlButton(symbol: "pause.fill", size: 18)
    private let nextButton = NowPlayingControlButton(symbol: "forward.fill", size: 14)

    private let artworkSize: CGFloat = 44
    private let buttonSize: CGFloat = 32

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .white
        artistLabel.font = .systemFont(ofSize: 11)
        artistLabel.textColor = .white.withAlphaComponent(0.6)
        for label in [titleLabel, artistLabel] {
            label.lineBreakMode = .byTruncatingTail
            addSubview(label)
        }
        addSubview(artworkView)
        addSubview(visualizer)

        previousButton.onClick = { [weak self] in self?.onCommand?(.previousTrack) }
        playPauseButton.onClick = { [weak self] in self?.onCommand?(.togglePlayPause) }
        nextButton.onClick = { [weak self] in self?.onCommand?(.nextTrack) }
        [previousButton, playPauseButton, nextButton].forEach(addSubview)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ state: NowPlayingState?) {
        guard let state else { return }
        titleLabel.stringValue = state.title
        artistLabel.stringValue = state.artist
        artworkView.setArtwork(state.artwork)
        visualizer.setAnimating(state.isPlaying)
        playPauseButton.setSymbol(state.isPlaying ? "pause.fill" : "play.fill")
    }

    override func layout() {
        super.layout()
        artworkView.frame = NSRect(
            x: 0, y: (bounds.height - artworkSize) / 2, width: artworkSize, height: artworkSize)

        let controlsWidth = 3 * buttonSize
        let controlsX = bounds.width - controlsWidth
        for (index, button) in [previousButton, playPauseButton, nextButton].enumerated() {
            button.frame = NSRect(
                x: controlsX + CGFloat(index) * buttonSize, y: (bounds.height - buttonSize) / 2,
                width: buttonSize, height: buttonSize)
        }

        let vizSize = visualizer.intrinsicContentSize
        visualizer.frame = NSRect(
            x: controlsX - 12 - vizSize.width, y: (bounds.height - vizSize.height) / 2,
            width: vizSize.width, height: vizSize.height)

        let textX = artworkView.frame.maxX + 10
        let textWidth = max(0, visualizer.frame.minX - 10 - textX)
        let lineHeight: CGFloat = 16
        titleLabel.frame = NSRect(x: textX, y: bounds.midY + 1, width: textWidth, height: lineHeight)
        artistLabel.frame = NSRect(x: textX, y: bounds.midY - lineHeight, width: textWidth, height: lineHeight)
    }
}

/// Bouton-glyphe qui s'éclaircit au survol, sur le modèle de `NotchGearButtonView`.
final class NowPlayingControlButton: NSView {

    var onClick: (() -> Void)?

    private let iconView = NSImageView()
    private let pointSize: CGFloat
    private var isHovered = false {
        didSet { iconView.contentTintColor = .white.withAlphaComponent(isHovered ? 1 : 0.75) }
    }
    private var trackingArea: NSTrackingArea?

    init(symbol: String, size: CGFloat) {
        pointSize = size
        super.init(frame: .zero)
        iconView.imageScaling = .scaleProportionallyDown
        iconView.contentTintColor = .white.withAlphaComponent(0.75)
        addSubview(iconView)
        setSymbol(symbol)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setSymbol(_ name: String) {
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
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

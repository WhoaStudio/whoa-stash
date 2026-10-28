import AppKit

/// Lecteur de l'onglet Global, déplié : grande pochette, titre, « artiste - album » et nom de
/// l'application, barre de progression avec temps écoulé et restant, précédent / lecture-pause /
/// suivant, et le volume du système. Les ailes de l'encoche sont trop étroites pour porter tout
/// cela — c'est ici qu'on pilote.
final class NowPlayingRowView: NSView {

    var onCommand: ((NowPlayingCommand) -> Void)?

    private let artworkView = ArtworkView()
    private let titleLabel = NowPlayingRowView.label(size: 20, weight: .semibold, color: .white)
    private let subtitleLabel = NowPlayingRowView.label(size: 14, weight: .regular, color: .white.withAlphaComponent(0.45))
    private let sourceLabel = NowPlayingRowView.label(size: 14, weight: .regular, color: .white.withAlphaComponent(0.45))
    private let elapsedLabel = NowPlayingRowView.label(size: 11, weight: .regular, color: .white.withAlphaComponent(0.45))
    private let remainingLabel = NowPlayingRowView.label(size: 11, weight: .regular, color: .white.withAlphaComponent(0.45))
    private let progress = NowPlayingSliderView(isInteractive: false)
    private let volumeSlider = NowPlayingSliderView(isInteractive: true)
    private let volumeIcon = NSImageView()
    private let previousButton = NowPlayingControlButton(symbol: "backward.fill", size: 18)
    private let playPauseButton = NowPlayingControlButton(symbol: "pause.fill", size: 24)
    private let nextButton = NowPlayingControlButton(symbol: "forward.fill", size: 18)

    private var state: NowPlayingState?
    private var tickTimer: Timer?

    private let gap: CGFloat = 16
    private let buttonSize: CGFloat = 36
    private let volumeWidth: CGFloat = 150

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        artworkView.showsSourceBadge = false
        addSubview(artworkView)

        titleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.lineBreakMode = .byTruncatingTail
        sourceLabel.alignment = .right
        elapsedLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        remainingLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        remainingLabel.alignment = .right
        for view in [titleLabel, subtitleLabel, sourceLabel, elapsedLabel, remainingLabel, progress] as [NSView] {
            addSubview(view)
        }

        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
        volumeIcon.image = NSImage(systemSymbolName: "speaker.fill", accessibilityDescription: "Volume")?
            .withSymbolConfiguration(configuration)
        volumeIcon.contentTintColor = .white.withAlphaComponent(0.45)
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
            subtitleLabel.stringValue = ""
            sourceLabel.stringValue = ""
            artworkView.setArtwork(nil)
            playPauseButton.setSymbol("play.fill")
            updateProgress()
            return
        }
        titleLabel.stringValue = state.title
        subtitleLabel.stringValue = [state.artist, state.album].filter { !$0.isEmpty }.joined(separator: " - ")
        sourceLabel.stringValue = Self.sourceName(for: state.bundleIdentifier)
        artworkView.setArtwork(state.artwork)
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
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// Nom affiché pour l'application qui joue ; l'identifiant brut si le système ne la connaît pas.
    private static func sourceName(for bundleIdentifier: String) -> String {
        // Musique s'appelle « Music » sur le disque ; son nom commercial est celui qu'on attend ici.
        if bundleIdentifier == "com.apple.Music" { return "Apple Music" }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return bundleIdentifier
        }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    override func layout() {
        super.layout()
        let artSize = min(bounds.height, 112)
        artworkView.frame = NSRect(x: 0, y: (bounds.height - artSize) / 2, width: artSize, height: artSize)

        let left = artworkView.frame.maxX + gap
        let width = max(0, bounds.width - left)
        let top = artworkView.frame.maxY

        titleLabel.frame = NSRect(x: left, y: top - 28, width: width, height: 26)
        let sourceWidth = min(sourceLabel.intrinsicContentSize.width, width / 3)
        sourceLabel.frame = NSRect(x: left + width - sourceWidth, y: top - 52, width: sourceWidth, height: 20)
        subtitleLabel.frame = NSRect(x: left, y: top - 52, width: max(0, width - sourceWidth - 8), height: 20)

        progress.frame = NSRect(x: left, y: top - 66, width: width, height: 8)
        elapsedLabel.frame = NSRect(x: left, y: top - 84, width: width / 2, height: 15)
        remainingLabel.frame = NSRect(x: left + width / 2, y: top - 84, width: width / 2, height: 15)

        let controlsY = artworkView.frame.minY
        for (index, button) in [previousButton, playPauseButton, nextButton].enumerated() {
            button.frame = NSRect(
                x: left + CGFloat(index) * (buttonSize + 4), y: controlsY,
                width: buttonSize, height: buttonSize)
        }

        volumeSlider.frame = NSRect(
            x: bounds.maxX - volumeWidth, y: controlsY + (buttonSize - 16) / 2, width: volumeWidth, height: 16)
        volumeIcon.frame = NSRect(
            x: volumeSlider.frame.minX - 26, y: controlsY + (buttonSize - 16) / 2, width: 18, height: 16)
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

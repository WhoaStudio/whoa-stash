import AppKit

/// Contenu des deux ailes de l'encoche pendant la lecture : la pochette à gauche, le
/// visualiseur à droite, le centre restant à l'encoche matérielle. Même gabarit que
/// `DeviceStatusPillView`, dont il reprend la largeur d'aile et les marges.
///
/// Pas de fond : la silhouette élargie par `NotchPanelContentView` en fait office. Mise en page
/// en frames ; la vue ne reçoit aucun événement.
final class NowPlayingWingsView: NSView {

    private let artworkView = ArtworkView()
    private let visualizer = AudioVisualizerView()

    private let inset: CGFloat = 18
    private let artworkSize: CGFloat = 22

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        addSubview(artworkView)
        addSubview(visualizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func apply(_ state: NowPlayingState) {
        artworkView.setArtwork(state.artwork)
        visualizer.setAnimating(state.isPlaying)
    }

    override func layout() {
        super.layout()
        artworkView.frame = NSRect(
            x: inset, y: (bounds.height - artworkSize) / 2, width: artworkSize, height: artworkSize)
        let size = visualizer.intrinsicContentSize
        visualizer.frame = NSRect(
            x: bounds.width - inset - size.width, y: (bounds.height - size.height) / 2,
            width: size.width, height: size.height)
    }
}

/// Pochette arrondie ; un glyphe de note tient lieu d'image tant qu'il n'y en a pas (elle arrive
/// parfois après le titre).
final class ArtworkView: NSView {

    private let imageView = NSImageView()
    private var currentData: Data?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.contentTintColor = .white.withAlphaComponent(0.7)
        addSubview(imageView)
        showPlaceholder()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
    }

    func setArtwork(_ data: Data?) {
        guard data != currentData else { return }
        currentData = data
        if let data, let image = NSImage(data: data) {
            imageView.imageScaling = .scaleAxesIndependently
            imageView.image = image
        } else {
            showPlaceholder()
        }
    }

    private func showPlaceholder() {
        imageView.imageScaling = .scaleProportionallyDown
        imageView.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
    }
}

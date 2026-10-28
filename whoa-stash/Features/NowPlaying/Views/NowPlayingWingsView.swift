import AppKit

/// Contenu des deux ailes de l'encoche pendant la lecture : la pochette à gauche, le
/// visualiseur à droite, le centre restant à l'encoche matérielle. Même gabarit que
/// `DeviceStatusPillView`, avec des ailes plus étroites.
///
/// Pas de fond : la silhouette élargie par `NotchPanelContentView` en fait office. Mise en page
/// en frames ; la vue ne reçoit aucun événement.
final class NowPlayingWingsView: NSView {

    private let artworkView = ArtworkView()
    private let visualizer = AudioVisualizerView()

    /// Largeur de chaque aile, de part et d'autre de l'encoche : plus étroite que celle de la
    /// pastille Bluetooth, qui n'a pas à porter de pochette plus grande.
    static let wingWidth: CGFloat = 60

    /// Hauteur ajoutée à l'encoche pendant la lecture.
    static let extraHeight: CGFloat = 2

    private let inset: CGFloat = 14
    private let artworkSize: CGFloat = 28

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
        artworkView.setSource(bundleIdentifier: state.bundleIdentifier)
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

/// Pochette arrondie, avec en bas à droite l'icône de l'application qui joue (Spotify, Musique,
/// le navigateur). Un glyphe de note tient lieu d'image tant qu'il n'y en a pas : elle arrive
/// parfois après le titre.
final class ArtworkView: NSView {

    private let imageView = NSImageView()
    private let badgeView = NSImageView()
    private var currentData: Data?
    private var currentSource: String?

    var showsSourceBadge = true {
        didSet { badgeView.isHidden = !showsSourceBadge || badgeView.image == nil }
    }

    /// Taille de l'icône (part du côté de la pochette) et retrait depuis le coin bas droit :
    /// négatif, elle déborde de la pochette ; positif, elle se pose dedans.
    var badgeScale: CGFloat = 0.5 { didSet { needsLayout = true } }
    var badgeInset: CGFloat = -3 { didSet { needsLayout = true } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        // Le coin arrondi est sur l'image seule : l'icône déborde un peu de la pochette.
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 7
        imageView.layer?.masksToBounds = true
        imageView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.12).cgColor
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.contentTintColor = .white.withAlphaComponent(0.7)
        addSubview(imageView)

        badgeView.imageScaling = .scaleProportionallyUpOrDown
        badgeView.isHidden = true
        addSubview(badgeView)
        showPlaceholder()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
        let badge = (bounds.width * badgeScale).rounded()
        badgeView.frame = NSRect(
            x: bounds.maxX - badge - badgeInset, y: bounds.minY + badgeInset, width: badge, height: badge)
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

    /// Icône de l'application dont on donne l'identifiant ; rien si le système ne la connaît pas.
    func setSource(bundleIdentifier: String) {
        guard bundleIdentifier != currentSource else { return }
        currentSource = bundleIdentifier
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            badgeView.image = NSWorkspace.shared.icon(forFile: url.path)
            badgeView.isHidden = !showsSourceBadge
        } else {
            badgeView.image = nil
            badgeView.isHidden = true
        }
    }

    /// Retire l'icône : plus rien ne joue.
    func clearSource() {
        currentSource = nil
        badgeView.image = nil
        badgeView.isHidden = true
    }

    private func showPlaceholder() {
        imageView.imageScaling = .scaleProportionallyDown
        imageView.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
    }
}

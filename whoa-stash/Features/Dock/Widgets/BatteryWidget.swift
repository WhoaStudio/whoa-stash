import AppKit

/// Tuile « batterie » : un anneau qui se remplit dans le sens horaire depuis midi, et le niveau
/// au centre, sans signe %.
@MainActor
final class BatteryWidget: DockWidget {

    static let kind = DockWidgetKind(id: "battery", title: "Battery", symbol: "battery.100") {
        BatteryWidget(provider: MockBatteryProvider.fromLaunchArguments() ?? IOKitBatteryProvider())
    }

    private let provider: BatteryProviding
    private let tile = BatteryTileView()
    var view: NSView { tile }

    init(provider: BatteryProviding) {
        self.provider = provider
        provider.onChange = { [weak tile] in tile?.percent = $0 }
    }

    func start() { provider.start() }
    func stop() { provider.stop() }
}

/// Le dessin de la tuile. Séparé du widget pour se rendre sans source de données.
final class BatteryTileView: NSView {

    /// Remplissage de l'anneau pour `percent` : 0...1, sans sortir de l'intervalle.
    static func fraction(percent: Int?) -> CGFloat {
        guard let percent else { return 0 }
        return CGFloat(min(100, max(0, percent))) / 100
    }

    /// Un cercle qui part de midi et tourne dans le sens horaire.
    static func ringPath(in rect: CGRect) -> CGPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let path = CGMutablePath()
        path.addArc(center: center, radius: radius, startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi, clockwise: true)
        return path
    }

    var percent: Int? {
        didSet {
            guard percent != oldValue else { return }
            refresh()
        }
    }

    private let track = CAShapeLayer()
    private let fill = CAShapeLayer()
    private let label = NSTextField(labelWithString: "–")

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.17, alpha: 1).cgColor
        for ring in [track, fill] {
            ring.fillColor = nil
            layer?.addSublayer(ring)
        }
        track.strokeColor = NSColor(white: 0.30, alpha: 1).cgColor
        fill.strokeColor = NSColor(hex: "#2FD158").cgColor
        fill.lineCap = .round
        label.textColor = .white
        label.alignment = .center
        addSubview(label)
        refresh()
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    private func refresh() {
        fill.strokeEnd = Self.fraction(percent: percent)
        // Un arc de longueur nulle avec un bout arrondi laisse un point : on le masque.
        fill.isHidden = fill.strokeEnd == 0
        label.stringValue = percent.map(String.init) ?? "–"
    }

    override func layout() {
        super.layout()
        let side = min(bounds.width, bounds.height)
        layer?.cornerRadius = side * 0.24
        let lineWidth = side * 0.09
        let ringRect = bounds.insetBy(dx: side * 0.17, dy: side * 0.17)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for ring in [track, fill] {
            ring.frame = bounds
            ring.lineWidth = lineWidth
            ring.path = Self.ringPath(in: ringRect)
        }
        CATransaction.commit()
        label.font = .systemFont(ofSize: side * 0.34, weight: .semibold)
        label.sizeToFit()
        label.frame = NSRect(
            x: (bounds.width - label.frame.width) / 2, y: (bounds.height - label.frame.height) / 2,
            width: label.frame.width, height: label.frame.height)
    }
}

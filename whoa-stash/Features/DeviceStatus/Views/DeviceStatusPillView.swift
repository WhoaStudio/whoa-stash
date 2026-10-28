import AppKit

/// Pastille d'état d'un appareil Bluetooth : une capsule noire portant le glyphe de l'appareil,
/// son nom, puis la batterie — bague verte pour des écouteurs, barre verte et pourcentage pour un
/// niveau unique, rien quand le niveau est inconnu.
///
/// Mise en page en frames, comme le reste de l'overlay ; la vue ne reçoit aucun événement.
final class DeviceStatusPillView: NSView {

    static let size = NSSize(width: 300, height: 56)

    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let percentLabel = NSTextField(labelWithString: "")
    private let ringTrack = CAShapeLayer()
    private let ringProgress = CAShapeLayer()
    private let barTrack = CALayer()
    private let barFill = CALayer()

    private var indicator: DeviceBattery.Indicator?

    private let inset: CGFloat = 20
    private let iconSize: CGFloat = 28
    private let ringDiameter: CGFloat = 26
    private let barSize = NSSize(width: 56, height: 8)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerCurve = .continuous
        // Même ombre diffuse que la silhouette de l'encoche, un peu plus douce.
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.3
        layer?.shadowRadius = 12
        layer?.shadowOffset = CGSize(width: 0, height: -4)

        iconView.contentTintColor = .white
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        for label in [nameLabel, percentLabel] {
            label.textColor = .white
            label.lineBreakMode = .byTruncatingTail
            addSubview(label)
        }
        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        percentLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        percentLabel.alignment = .right

        for shape in [ringTrack, ringProgress] {
            shape.fillColor = nil
            shape.lineWidth = 3.5
            shape.lineCap = .round
            layer?.addSublayer(shape)
        }
        ringTrack.strokeColor = NSColor.white.withAlphaComponent(0.18).cgColor
        ringProgress.strokeEnd = 0

        barTrack.backgroundColor = NSColor.white.withAlphaComponent(0.18).cgColor
        layer?.addSublayer(barTrack)
        layer?.addSublayer(barFill)
        barFill.anchorPoint = CGPoint(x: 0, y: 0.5)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ status: DeviceStatus) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        iconView.image = NSImage(systemSymbolName: status.kind.symbolName, accessibilityDescription: status.name)?
            .withSymbolConfiguration(configuration)
        nameLabel.stringValue = status.name
        indicator = status.battery?.indicator
        needsLayout = true
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2

        iconView.frame = NSRect(
            x: inset, y: (bounds.height - iconSize) / 2, width: iconSize, height: iconSize)

        var trailing = bounds.width - inset
        let tint = Self.tint(for: indicator)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ringTrack.isHidden = true
        ringProgress.isHidden = true
        barTrack.isHidden = true
        barFill.isHidden = true
        percentLabel.isHidden = true

        switch indicator {
        case .ring(let percent):
            let rect = NSRect(
                x: trailing - ringDiameter, y: (bounds.height - ringDiameter) / 2,
                width: ringDiameter, height: ringDiameter)
            // Part de midi, sens horaire : un cercle tracé depuis le haut vers la droite.
            let path = CGMutablePath()
            path.addArc(
                center: CGPoint(x: rect.midX, y: rect.midY), radius: (ringDiameter - 3.5) / 2,
                startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi, clockwise: true)
            for shape in [ringTrack, ringProgress] {
                shape.frame = bounds
                shape.path = path
                shape.isHidden = false
            }
            ringProgress.strokeColor = tint
            ringProgress.strokeEnd = CGFloat(percent) / 100
            trailing = rect.minX
        case .bar(let percent):
            percentLabel.stringValue = "\(percent)"
            percentLabel.sizeToFit()
            let labelWidth: CGFloat = 34
            percentLabel.frame = NSRect(
                x: trailing - labelWidth, y: (bounds.height - percentLabel.frame.height) / 2,
                width: labelWidth, height: percentLabel.frame.height)
            percentLabel.isHidden = false
            let barFrame = CGRect(
                x: percentLabel.frame.minX - 14 - barSize.width,
                y: (bounds.height - barSize.height) / 2,
                width: barSize.width, height: barSize.height)
            barTrack.frame = barFrame
            barTrack.cornerRadius = barSize.height / 2
            barFill.bounds = CGRect(
                x: 0, y: 0, width: barSize.width * CGFloat(percent) / 100, height: barSize.height)
            barFill.position = CGPoint(x: barFrame.minX, y: barFrame.midY)
            barFill.cornerRadius = barSize.height / 2
            barFill.backgroundColor = tint
            barTrack.isHidden = false
            barFill.isHidden = false
            trailing = barFrame.minX
        case nil:
            break
        }
        CATransaction.commit()

        nameLabel.sizeToFit()
        let nameX = iconView.frame.maxX + 20
        let nameWidth = max(0, min(nameLabel.frame.width, trailing - 14 - nameX))
        nameLabel.frame = NSRect(
            x: nameX, y: (bounds.height - nameLabel.frame.height) / 2,
            width: nameWidth, height: nameLabel.frame.height)
    }

    /// Vert, ou orange sous 20 % pour signaler une batterie faible.
    private static func tint(for indicator: DeviceBattery.Indicator?) -> CGColor {
        let percent: Int
        switch indicator {
        case .ring(let value), .bar(let value): percent = value
        case nil: percent = 100
        }
        return (percent < 20 ? NSColor.systemOrange : NSColor.systemGreen).cgColor
    }
}

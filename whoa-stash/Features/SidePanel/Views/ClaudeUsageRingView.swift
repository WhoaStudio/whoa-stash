import AppKit

/// Case de l'extension du Dock montrant l'utilisation de la session Claude : un anneau qui se
/// remplit dans le sens horaire depuis midi, l'étoile Claude au centre, et le pourcentage
/// dessous. Même grammaire d'interaction que `DockExtensionIconView` (survol et clic au
/// ressort), mais tout est en calques : le texte aussi, pour que la mise à l'échelle du survol
/// emporte l'ensemble d'un seul bloc.
final class ClaudeUsageRingView: NSView {

    /// Entrée/sortie du curseur sur la case, avec le cadre de la bague en coordonnées écran :
    /// c'est ce cadre qui ancre la bulle d'utilisation, et il n'est connu que d'ici — la case se
    /// déplace avec le Dock et change de taille avec lui.
    var onHoverChanged: ((Bool, NSRect) -> Void)?

    private let contentLayer = CALayer()
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let markLayer = CAShapeLayer()
    private let percentLayer = CATextLayer()

    private var trackingArea: NSTrackingArea?
    private var state: ClaudeUsageState = .loading

    /// Proportions de la case, toutes relatives à `tileSize` : le Dock système change de taille
    /// avec les préférences de l'utilisateur, et l'anneau doit suivre sans constante codée.
    private let labelHeightRatio: CGFloat = 0.24
    private let gapRatio: CGFloat = 0.04
    private let strokeWidthRatio: CGFloat = 0.11
    private let markDiameterRatio: CGFloat = 0.46

    init(tileSize: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: tileSize, height: tileSize))
        wantsLayer = true
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        contentLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer?.addSublayer(contentLayer)

        for shape in [trackLayer, progressLayer] {
            shape.fillColor = nil
            shape.lineCap = .round
            contentLayer.addSublayer(shape)
        }
        // L'anneau part de midi et tourne dans le sens horaire : c'est le chemin lui-même qui
        // porte cette orientation, `strokeEnd` n'a plus qu'à exprimer la fraction remplie.
        progressLayer.strokeEnd = 0

        contentLayer.addSublayer(markLayer)

        percentLayer.alignmentMode = .center
        percentLayer.truncationMode = .none
        contentLayer.addSublayer(percentLayer)

        applyAppearance()
        applyState(animated: false)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyAppearance()
        applyState(animated: false)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Sans ça, `CATextLayer` rend flou sur écran Retina : contrairement à un NSTextField,
        // il ne récupère pas l'échelle de la fenêtre tout seul.
        let scale = window?.backingScaleFactor ?? 2
        percentLayer.contentsScale = scale
        markLayer.contentsScale = scale
    }

    // MARK: - État

    func apply(_ newState: ClaudeUsageState, animated: Bool) {
        state = newState
        applyState(animated: animated)
    }

    private func applyState(animated: Bool) {
        let session = state.snapshot?.session

        let fill = session.map { CGFloat($0.utilization) } ?? 0
        let color = session.map { ClaudeUsagePalette.color(for: $0.utilization) }
            ?? ClaudeUsagePalette.unavailable(for: effectiveAppearance)

        if animated {
            progressLayer.springAnimate(keyPath: "strokeEnd", to: fill, preset: .snappy)
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            progressLayer.strokeEnd = fill
            CATransaction.commit()
        }

        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        progressLayer.strokeColor = color
        markLayer.fillColor = color
        percentLayer.foregroundColor = NSColor.labelColor.cgColor
        CATransaction.commit()

        switch state {
        case .loaded(let snapshot):
            percentLayer.string = "\(snapshot.session.percentage)%"
            toolTip = "Claude — session \(snapshot.session.percentage) % · tous modèles \(snapshot.allModels.percentage) %"
        case .loading:
            percentLayer.string = "–"
            toolTip = "Claude — chargement de l'utilisation…"
        case .unavailable(let reason):
            percentLayer.string = "–"
            toolTip = "Claude — \(reason)"
        }
    }

    private func applyAppearance() {
        trackLayer.strokeColor = ClaudeUsagePalette.track(for: effectiveAppearance)
    }

    // MARK: - Mise en page

    override func layout() {
        super.layout()

        contentLayer.frame = bounds
        contentLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)

        let tileSize = min(bounds.width, bounds.height)
        let labelHeight = tileSize * labelHeightRatio
        let gap = tileSize * gapRatio
        let ringDiameter = min(bounds.width, bounds.height - labelHeight - gap)
        let strokeWidth = ringDiameter * strokeWidthRatio

        // L'anneau occupe le haut de la case, le pourcentage se loge dessous — comme dans la
        // référence, où le chiffre est posé sous la bague et non à l'intérieur.
        let ringCenter = CGPoint(x: bounds.midX, y: bounds.maxY - ringDiameter / 2)
        let radius = (ringDiameter - strokeWidth) / 2

        let circle = CGMutablePath()
        circle.addArc(
            center: ringCenter,
            radius: radius,
            startAngle: .pi / 2,
            endAngle: .pi / 2 - 2 * .pi,
            clockwise: true
        )

        for shape in [trackLayer, progressLayer] {
            shape.frame = bounds
            shape.path = circle
            shape.lineWidth = strokeWidth
        }

        let markDiameter = ringDiameter * markDiameterRatio
        markLayer.frame = bounds
        markLayer.path = ClaudeMarkPath.path(
            in: CGRect(
                x: ringCenter.x - markDiameter / 2,
                y: ringCenter.y - markDiameter / 2,
                width: markDiameter,
                height: markDiameter
            )
        )

        let fontSize = labelHeight * 0.86
        percentLayer.font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        percentLayer.fontSize = fontSize
        percentLayer.frame = NSRect(x: 0, y: bounds.minY, width: bounds.width, height: labelHeight)
    }

    // MARK: - Survol et clic

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        contentLayer.springAnimate(keyPath: "transform.scale", to: 1.15, preset: .snappy)
        onHoverChanged?(true, screenRect)
    }

    override func mouseExited(with event: NSEvent) {
        contentLayer.springAnimate(keyPath: "transform.scale", to: 1.0, preset: .snappy)
        onHoverChanged?(false, screenRect)
    }

    override func mouseDown(with event: NSEvent) {
        contentLayer.springAnimate(keyPath: "transform.scale", to: 0.88, preset: .snappy)
    }

    /// Pas de callback au clic : la bulle d'utilisation est déjà ouverte, puisqu'il faut survoler
    /// la bague pour la cliquer. Seul le ressort d'enfoncement subsiste.
    override func mouseUp(with event: NSEvent) {
        let insideAfterRelease = bounds.contains(convert(event.locationInWindow, from: nil))
        contentLayer.springAnimate(keyPath: "transform.scale", to: insideAfterRelease ? 1.15 : 1.0, preset: .snappy)
    }

    /// Cadre de la case en coordonnées globales AppKit, le repère dans lequel raisonnent
    /// `SidePanelGeometry` et `SidePanelController`.
    var screenRect: NSRect {
        guard let window else { return .zero }
        return window.convertToScreen(convert(bounds, to: nil))
    }
}

import AppKit

/// Les trois calques d'une bague d'utilisation : la piste, le ruban qui se remplit dans le sens
/// horaire depuis midi, et l'étoile Claude au centre.
///
/// Partagé par la case du Dock (`ClaudeUsageRingView`) et l'en-tête de la carte
/// (`ClaudeUsagePanelView`) : les deux surfaces montrent le même instantané, elles doivent donc
/// montrer exactement la même bague — même sens de remplissage, même seuil de couleur, même
/// proportion d'étoile — à deux tailles près. Tout est exprimé en fraction du diamètre pour que
/// la case suive la taille du Dock système sans que l'en-tête bouge.
///
/// N'est pas une `NSView` : les deux hôtes posent ces calques dans leur propre hiérarchie, l'un
/// dans un calque qu'il met à l'échelle au survol, l'autre à même la vue.
final class ClaudeUsageRing {

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let markLayer = CAShapeLayer()

    private let strokeWidthRatio: CGFloat
    private let markDiameterRatio: CGFloat
    private let tintsMark: Bool

    /// Couleur de l'étoile quand `tintsMark` est faux — l'en-tête de la carte garde une étoile
    /// blanche, seule la bague autour d'elle porte la couleur du taux.
    var markColor: CGColor?

    init(strokeWidthRatio: CGFloat = 0.11, markDiameterRatio: CGFloat = 0.46, tintsMark: Bool = true) {
        self.strokeWidthRatio = strokeWidthRatio
        self.markDiameterRatio = markDiameterRatio
        self.tintsMark = tintsMark
    }

    func install(in parent: CALayer) {
        for shape in [trackLayer, progressLayer] {
            shape.fillColor = nil
            shape.lineCap = .round
            parent.addSublayer(shape)
        }
        // L'anneau part de midi et tourne dans le sens horaire : c'est le chemin lui-même qui
        // porte cette orientation, `strokeEnd` n'a plus qu'à exprimer la fraction remplie.
        progressLayer.strokeEnd = 0
        parent.addSublayer(markLayer)
    }

    /// Sans ça, l'étoile rend floue sur écran Retina : un `CAShapeLayer` ne récupère pas
    /// l'échelle de la fenêtre tout seul.
    func setContentsScale(_ scale: CGFloat) {
        markLayer.contentsScale = scale
    }

    /// `frame` est le repère des calques (les `bounds` de la vue hôte) ; la bague est centrée sur
    /// `center` et fait `diameter` de large, ruban compris.
    func layout(in frame: CGRect, center: CGPoint, diameter: CGFloat) {
        let strokeWidth = diameter * strokeWidthRatio
        let radius = (diameter - strokeWidth) / 2

        let circle = CGMutablePath()
        circle.addArc(
            center: center,
            radius: radius,
            startAngle: .pi / 2,
            endAngle: .pi / 2 - 2 * .pi,
            clockwise: true
        )

        for shape in [trackLayer, progressLayer] {
            shape.frame = frame
            shape.path = circle
            shape.lineWidth = strokeWidth
        }

        let markDiameter = diameter * markDiameterRatio
        markLayer.frame = frame
        markLayer.path = ClaudeMarkPath.path(
            in: CGRect(
                x: center.x - markDiameter / 2,
                y: center.y - markDiameter / 2,
                width: markDiameter,
                height: markDiameter
            )
        )
    }

    func applyAppearance(_ appearance: NSAppearance) {
        trackLayer.strokeColor = ClaudeUsagePalette.track(for: appearance)
    }

    /// `utilization` à `nil` : pas d'instantané connu — la bague reste vide et prend la teinte
    /// neutre, plutôt que de montrer un 0 % qui serait une vraie valeur.
    func apply(utilization: Double?, appearance: NSAppearance, animated: Bool) {
        let fill = utilization.map { CGFloat($0) } ?? 0
        let color = utilization.map { ClaudeUsagePalette.color(for: $0) }
            ?? ClaudeUsagePalette.unavailable(for: appearance)

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
        markLayer.fillColor = tintsMark ? color : (markColor ?? color)
        CATransaction.commit()
    }
}

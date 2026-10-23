import CoreGraphics

/// Marques des fournisseurs portées au centre des bagues, dessinées en chemins plutôt que
/// chargées comme images : elles doivent rendre net à n'importe quelle taille de case, sans
/// embarquer un jeu de PNG pour chaque échelle. Même parti pris que `ClaudeMarkPath`, dont
/// l'étoile Claude reste la référence de poids optique pour les deux autres.
enum UsageMarkPath {
    case claude
    case codex
    case gemini

    func path(in rect: CGRect) -> CGPath {
        switch self {
        case .claude: return ClaudeMarkPath.path(in: rect)
        case .codex: return Self.codexPath(in: rect)
        case .gemini: return Self.geminiPath(in: rect)
        }
    }

    /// Nœud à trois boucles : trois anneaux allongés tournés de 60°, tracés en trait d'épaisseur
    /// constante puis convertis en surface pleine. C'est une approximation de la fleur OpenAI —
    /// même construction en boucles entrelacées et même poids optique que l'étoile Claude, sans
    /// être le tracé officiel.
    private static func codexPath(in rect: CGRect) -> CGPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        let loop = CGSize(width: radius * 1.72, height: radius * 0.86)
        let lineWidth = radius * 0.22

        let outline = CGMutablePath()
        for index in 0..<3 {
            let angle = (.pi / 3) * CGFloat(index)
            let transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle)
            outline.addPath(
                CGPath(
                    ellipseIn: CGRect(x: -loop.width / 2, y: -loop.height / 2, width: loop.width, height: loop.height),
                    transform: nil
                ),
                transform: transform
            )
        }
        // Le trait devient la surface : `markLayer` remplit, il ne trace pas.
        return outline.copy(strokingWithWidth: lineWidth, lineCap: .round, lineJoin: .round, miterLimit: 10)
    }

    /// Étincelle à quatre branches de Gemini : quatre pointes reliées par des creux qui passent
    /// près du centre, ce qui donne les flancs concaves caractéristiques.
    private static func geminiPath(in rect: CGRect) -> CGPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        // Plus le point de contrôle est près du centre, plus les flancs se creusent.
        let waist = outer * 0.15

        let tips = (0..<4).map { index -> CGPoint in
            let angle = (.pi / 2) * CGFloat(index) - .pi / 2
            return CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer)
        }

        let path = CGMutablePath()
        path.move(to: tips[0])
        for index in 0..<4 {
            let next = tips[(index + 1) % 4]
            // Le creux entre deux pointes, sur la bissectrice, ramené près du centre.
            let bisector = (.pi / 2) * CGFloat(index) - .pi / 4
            let control = CGPoint(x: center.x + cos(bisector) * waist, y: center.y + sin(bisector) * waist)
            path.addQuadCurve(to: next, control: control)
        }
        path.closeSubpath()
        return path
    }
}

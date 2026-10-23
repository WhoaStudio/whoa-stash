import CoreGraphics

/// Étoile Claude dessinée en chemin plutôt que chargée comme image : elle doit rendre net à
/// n'importe quelle taille de case du Dock (qui suit la taille réelle des icônes système) et
/// dans l'en-tête du panneau, sans embarquer un jeu de PNG pour chaque échelle.
enum ClaudeMarkPath {

    private static let rayCount = 11

    /// Rayons fuselés : larges près du centre, pointus à l'extérieur. C'est ce profil qui rend
    /// la marque reconnaissable à 14 pt, là où des traits d'épaisseur constante donnent une roue.
    static func path(in rect: CGRect) -> CGPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.13
        let halfInner = outer * 0.10
        let halfOuter = outer * 0.028

        let path = CGMutablePath()
        for index in 0..<rayCount {
            let angle = (2 * .pi / CGFloat(rayCount)) * CGFloat(index) - .pi / 2
            let transform = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle)

            let ray = CGMutablePath()
            ray.move(to: CGPoint(x: inner, y: -halfInner))
            ray.addLine(to: CGPoint(x: outer, y: -halfOuter))
            ray.addLine(to: CGPoint(x: outer, y: halfOuter))
            ray.addLine(to: CGPoint(x: inner, y: halfInner))
            ray.closeSubpath()

            path.addPath(ray, transform: transform)
        }
        return path
    }
}

import AppKit

/// Géométrie commune aux panneaux de l'overlay — les bandes accrochées à un bord vertical
/// (`SidePanelGeometry` à droite, le widget de luminosité à gauche) et le panneau de l'encoche
/// (`NotchPanelGeometry`). Les placements n'ont ni le même bord d'accroche ni la même
/// silhouette, mais ils doivent se lire comme plusieurs états d'une même surface : même rayon,
/// mêmes marges, même filet. Ces valeurs sont donc définies ici une fois, et chaque géométrie
/// s'y rapporte au lieu de les redire.
enum PanelGeometry {

    /// Rayon de la silhouette, convexe comme concave : c'est lui qui décide des marges, puisque
    /// les raccords rognent la zone peinte près du bord d'accroche.
    static let cornerRadius: CGFloat = 28

    /// Marges intérieures. La marge verticale vaut au moins le rayon : au-delà de cette ligne le
    /// bord peint se relève vers le bord d'accroche, et tout contenu qui y monterait sortirait du
    /// chemin.
    static let contentVerticalInset: CGFloat = cornerRadius + 6
    static let contentHorizontalInset: CGFloat = 14

    /// Écart entre deux blocs empilés dans le corps d'un panneau.
    static let contentSpacing: CGFloat = 14

    /// Épaisseur du filet tracé sur la frontière de la silhouette.
    static let strokeWidth: CGFloat = 1

    // MARK: - Cadre des bandes de bord

    /// Largeur d'une bande accrochée à un bord vertical. Les deux bords la partagent : posées
    /// face à face, les bandes doivent se répondre.
    static let panelWidth: CGFloat = 380

    /// Hauteur plancher, pour qu'une bande garde une silhouette posée même quand son contenu
    /// tient en moins. C'est aussi la hauteur de celles qui n'ont pas de contenu à mesurer.
    static let minimumPanelHeight: CGFloat = 300

    /// Marge sous le bas de la barre de menus, pour qu'une bande ne soit pas soudée à elle.
    static let topInset: CGFloat = 8

    /// Cadre affleurant le bord demandé, en coordonnées globales AppKit : c'est depuis ce bord
    /// que le contenu glisse, donc la bande doit y toucher — l'espacement visuel vient des coins
    /// arrondis, pas d'une marge. Le haut suit `visibleFrame` pour rester sous la barre de menus.
    ///
    /// Deux bandes posées sur les deux bords du même écran partagent donc cadre et hauteur : ce
    /// sont bien deux images l'une de l'autre.
    static func panelFrame(
        on screen: NSScreen,
        anchoredTo edge: EdgePosition,
        height: CGFloat = minimumPanelHeight
    ) -> NSRect {
        let top = screen.visibleFrame.maxY - topInset
        let x = edge == .right ? screen.frame.maxX - panelWidth : screen.frame.minX
        return NSRect(x: x, y: top - height, width: panelWidth, height: height)
    }

    // MARK: - Zone sensible

    /// Zone sensible d'une bande : 100 pt de haut sur 20 pt de large, mesurée depuis le coin
    /// supérieur de son bord d'accroche. On va chercher la bande là où elle vit — ailleurs sur
    /// le bord, elle s'ouvrirait loin du curseur qui l'a appelée.
    static let hotZoneWidth: CGFloat = 20
    static let hotZoneHeight: CGFloat = 100

    static func hotZone(on screen: NSScreen, anchoredTo edge: EdgePosition) -> NSRect {
        let frame = screen.frame
        return NSRect(
            x: edge == .right ? frame.maxX - hotZoneWidth : frame.minX,
            y: frame.maxY - hotZoneHeight,
            width: hotZoneWidth,
            height: hotZoneHeight
        )
    }

    // MARK: - Silhouette

    /// Silhouette complète en un seul chemin fermé : deux coins convexes du côté intérieur, et
    /// deux raccords **concaves** là où la bande rejoint le bord de l'écran, qui l'évasent comme
    /// un onglet de navigateur s'évase dans sa barre. Les arcs concaves sont décrits avec
    /// `addArc(center:radius:startAngle:endAngle:clockwise:)` et non avec la variante
    /// `tangent1End:tangent2End:`, qui ne sait produire que des coins convexes.
    ///
    /// Tout est dans le même `CGPath` : aucune couture entre le corps et les raccords, et tout ce
    /// qui est hors du chemin reste non peint, donc réellement transparent.
    ///
    /// Le chemin est tracé pour le bord droit, puis renvoyé en miroir autour de l'axe vertical du
    /// cadre quand on le demande à gauche — une bande de gauche est exactement celle de droite
    /// retournée, et deux tracés symétriques finiraient par diverger.
    static func silhouette(
        in rect: CGRect,
        anchoredTo edge: EdgePosition,
        cornerRadius requestedRadius: CGFloat = cornerRadius
    ) -> CGPath {
        let path = rightAnchoredSilhouette(in: rect, cornerRadius: requestedRadius)
        guard edge == .left else { return path }

        var mirror = CGAffineTransform(scaleX: -1, y: 1)
        mirror.tx = rect.minX + rect.maxX
        return path.copy(using: &mirror) ?? path
    }

    private static func rightAnchoredSilhouette(in rect: CGRect, cornerRadius: CGFloat) -> CGPath {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        let right = rect.maxX      // bord de l'écran
        let left = rect.minX
        let top = rect.maxY
        let bottom = rect.minY

        let path = CGMutablePath()

        // Haut : évasement concave depuis le bord, tangent vertical au contact de celui-ci.
        path.move(to: CGPoint(x: right, y: top))
        path.addArc(
            center: CGPoint(x: right - r, y: top),
            radius: r,
            startAngle: 0,
            endAngle: -.pi / 2,
            clockwise: true
        )

        // Coin convexe haut-intérieur.
        path.addLine(to: CGPoint(x: left + r, y: top - r))
        path.addArc(
            center: CGPoint(x: left + r, y: top - 2 * r),
            radius: r,
            startAngle: .pi / 2,
            endAngle: .pi,
            clockwise: false
        )

        // Côté intérieur, puis coin convexe bas-intérieur.
        path.addLine(to: CGPoint(x: left, y: bottom + 2 * r))
        path.addArc(
            center: CGPoint(x: left + r, y: bottom + 2 * r),
            radius: r,
            startAngle: .pi,
            endAngle: 3 * .pi / 2,
            clockwise: false
        )

        // Bas : évasement concave symétrique.
        path.addLine(to: CGPoint(x: right - r, y: bottom + r))
        path.addArc(
            center: CGPoint(x: right - r, y: bottom),
            radius: r,
            startAngle: .pi / 2,
            endAngle: 0,
            clockwise: true
        )

        // Remontée le long du bord de l'écran : la bande y reste en contact sur toute sa hauteur.
        path.closeSubpath()
        return path
    }
}

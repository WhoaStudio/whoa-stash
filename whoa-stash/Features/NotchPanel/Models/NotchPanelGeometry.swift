import AppKit

/// Géométrie du panneau de l'encoche pour un écran donné : la silhouette repliée (l'encoche
/// matérielle quand il y en a une, une pastille posée sous la barre de menus sinon), la
/// silhouette dépliée, et la zone sensible qui déclenche le dépliage. Tout est exprimé en
/// coordonnées globales AppKit (origine en bas à gauche de l'écran principal, axe Y vers le haut).
///
/// Jumelle de `SidePanelGeometry`, qui reste la géométrie du panneau du bord droit : les deux
/// placements coexistent, chacun avec son bord d'accroche et sa silhouette, mais ils tiennent
/// leur rayon, leurs marges, leurs écarts et leur filet de `PanelGeometry` — c'est ce qui les
/// fait se lire comme deux états d'une même surface.
enum NotchPanelGeometry {

    // MARK: - Silhouette

    /// Rayon des deux raccords **concaves** du haut, là où le panneau s'évase dans le bord
    /// auquel il est suspendu — le haut de l'écran sur un Mac à encoche, le bas de la barre de
    /// menus sinon.
    /// Le rayon replié est celui de la poignée du fonds commun : la silhouette doit se confondre
    /// avec l'encoche matérielle, qui est trop basse pour porter celui du panneau.
    static let collapsedShoulderRadius = PanelGeometry.collapsedShoulderRadius
    static let expandedShoulderRadius = PanelGeometry.cornerRadius

    /// Rayon des deux coins **convexes** du bas.
    static let collapsedBottomRadius = PanelGeometry.collapsedFarRadius
    static let expandedBottomRadius = PanelGeometry.cornerRadius

    // MARK: - État replié

    /// Largeur retenue quand l'écran annonce une encoche sans que la largeur des deux bandes de
    /// barre de menus soit lisible — l'encoche des MacBook actuels mesure environ cela.
    static let fallbackNotchWidth: CGFloat = 190

    /// Pastille affichée sur les Macs sans encoche : assez large pour se lire comme une poignée,
    /// assez basse pour ne rien masquer de ce qui est sous la barre de menus. C'est la poignée du
    /// fonds commun, posée ici sur le bord du haut.
    static let pillSize = PanelGeometry.collapsedHandleSize

    // MARK: - État déplié

    /// Marges intérieures du contenu. Celles de la bande du bord droit, mais prises dans le bon
    /// repère : ce panneau est suspendu au bord du **haut**, donc ce sont ses flancs gauche et
    /// droit qui courent le long du bord d'accroche — l'inverse d'une bande de flanc.
    ///
    /// La marge horizontale vaut donc au moins le rayon de la silhouette : les deux raccords
    /// concaves rentrent les flancs peints de `expandedShoulderRadius` de chaque côté, et tout
    /// contenu posé en deçà sort du chemin.
    static let contentInsetX = PanelGeometry.contentInsetAlongAnchor

    /// Ce que les coins convexes du bas rognent à l'aplomb du bord du contenu : la marge basse
    /// s'en augmente, sans quoi ce qui descend jusqu'en bas — le liseré du bac à fichiers —
    /// mordrait l'arrondi.
    static var bottomCornerBite: CGFloat {
        let offset = expandedShoulderRadius + expandedBottomRadius - contentInsetX
        guard abs(offset) < expandedBottomRadius else { return 0 }
        return expandedBottomRadius - (expandedBottomRadius * expandedBottomRadius - offset * offset).squareRoot()
    }

    static var contentInsetBottom: CGFloat {
        PanelGeometry.contentInsetAcrossAnchor + bottomCornerBite
    }

    /// Air entre le bas de la bande à laquelle le panneau est suspendu et le début du contenu.
    static let topClearance: CGFloat = 8

    /// Marge haute. En profondeur la silhouette est pleine, mais le cadre de la fenêtre part du
    /// bord haut de la dalle : le contenu doit donc passer sous la barre de menus et, sur un Mac
    /// à encoche, sous l'encoche elle-même, qui couvre le haut du panneau. La silhouette repliée
    /// mesure exactement cette bande — c'est elle qui fixe la marge, et non une constante qui ne
    /// vaudrait que pour une taille d'encoche.
    static func contentInsetTop(forCollapsedHeight collapsedHeight: CGFloat) -> CGFloat {
        max(PanelGeometry.contentInsetAcrossAnchor, collapsedHeight + topClearance)
    }

    // MARK: - Capsule de navigation

    /// Écart entre le bas du panneau et la capsule de navigation, qui flotte sous lui. Il est
    /// bien visible : la capsule n'est pas un morceau de la silhouette, et c'est ce vide qui le
    /// dit.
    static let capsuleGap: CGFloat = 10

    /// Bande basse du cadre de la fenêtre, sous la silhouette du panneau : l'écart, puis la
    /// capsule. Le panneau ne peint rien là — seule la capsule s'y pose.
    static var capsuleBandHeight: CGFloat {
        capsuleGap + TabBarMetrics.capsuleHeight
    }

    /// Bande de la semaine, en tête de l'onglet Global. Même vue que dans la bande du bord
    /// droit, donc même hauteur.
    static let weekStripHeight: CGFloat = 46

    /// Air entre la bande de la semaine et le widget calendrier, sous elle.
    static let calendarTopGap: CGFloat = 10

    /// Air entre l'en-tête de date et la liste des événements, dans le widget.
    static let calendarHeaderGap: CGFloat = 10

    /// Largeur de la grille du mois, colonne de droite du widget : sept colonnes de 28 pt, la
    /// plus petite largeur où deux chiffres tiennent sans se toucher.
    static let monthGridWidth: CGFloat = 196

    /// Hauteur du contenu de l'onglet Global : la bande de la semaine, puis le widget calendrier,
    /// dont la grille du mois fixe le plancher — six lignes de semaine plus leurs initiales.
    ///
    /// C'est cet onglet qui est désormais le plus haut, et donc lui qui dimensionne le panneau
    /// (voir `tabContentHeight`).
    static let globalTabHeight: CGFloat = 210

    /// Colonne de gauche de l'onglet AI : les bagues d'utilisation posées **en ligne** et non
    /// empilées, c'est tout ce qui distingue cette mise en page de celle de la bande du bord
    /// droit. Elles sont plus petites que celles de la bande : le panneau est resserré, et
    /// c'est la rangée entière qui doit tenir à côté de la carte.
    static let ringTileSize: CGFloat = 50
    static let ringSpacing: CGFloat = 16

    /// Écart de chaque côté du filet qui sépare les deux colonnes.
    static let columnGap: CGFloat = 18
    static let dividerWidth: CGFloat = 1

    /// Colonne de droite de l'onglet AI : la carte d'utilisation détaillée, aux dimensions que
    /// `ClaudeUsagePanelView` demande pour tenir son en-tête et ses deux lignes.
    static let cardSize = NSSize(width: 270, height: 190)

    static var ringRowWidth: CGFloat {
        let count = CGFloat(SidePanelGeometry.ringCount)
        return count * ringTileSize + max(0, count - 1) * ringSpacing
    }

    /// Hauteur du contenu d'un onglet, sous la barre : celle de l'onglet le plus haut — Global,
    /// depuis qu'il porte le widget calendrier —, pour que la silhouette dépliée ne change pas de
    /// taille d'un onglet à l'autre.
    static var tabContentHeight: CGFloat {
        max(globalTabHeight, cardSize.height)
    }

    /// Largeur du contenu de l'onglet le plus large — AI, avec ses deux colonnes.
    static var tabContentWidth: CGFloat {
        ringRowWidth + 2 * columnGap + dividerWidth + cardSize.width
    }

    /// Taille dépliée, capsule comprise : le cadre de la fenêtre porte les deux, et la hauteur
    /// est donc celle du panneau **plus** la bande basse où flotte la capsule.
    ///
    /// La largeur est celle du plus large de ce que la fenêtre porte : les deux colonnes de
    /// l'onglet AI, ou la capsule — c'est le panneau qui s'élargit, jamais la capsule qui
    /// déborde de lui.
    static func expandedSize(collapsedHeight: CGFloat) -> NSSize {
        NSSize(
            width: 2 * contentInsetX + max(tabContentWidth, NotchTabCapsuleView.width),
            height: contentInsetTop(forCollapsedHeight: collapsedHeight)
                + tabContentHeight
                + contentInsetBottom
                + capsuleBandHeight
        )
    }

    static func expandedSize(on screen: NSScreen) -> NSSize {
        expandedSize(collapsedHeight: collapsedSize(on: screen).height)
    }

    // MARK: - Encoche

    /// Cadre de l'encoche matérielle, `nil` sur un écran qui n'en a pas.
    ///
    /// La largeur est déduite des deux bandes de barre de menus laissées libres de part et
    /// d'autre de la caméra, et non de leurs abscisses : selon l'écran, `auxiliaryTopLeftArea`
    /// est donné dans le repère de l'écran ou dans le repère global, alors que les largeurs,
    /// elles, ne dépendent d'aucune origine. L'encoche étant centrée sur la dalle, cela suffit
    /// à la situer.
    static func notchRect(on screen: NSScreen) -> NSRect? {
        let height = screen.safeAreaInsets.top
        guard height > 0 else { return nil }

        let width: CGFloat
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let measured = screen.frame.width - left.width - right.width
            width = measured > 0 ? measured : fallbackNotchWidth
        } else {
            width = fallbackNotchWidth
        }

        return NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
    }

    /// Bord auquel le panneau est suspendu : toujours le haut de la dalle. Sur un Mac à encoche
    /// la silhouette repliée s'y confond avec l'encoche ; ailleurs la pastille s'y accroche de la
    /// même façon, au milieu de la barre de menus, là où ne vont ni les menus de l'application ni
    /// les icônes d'état. `visibleFrame` s'arrête sous cette barre — c'est lui qui laissait un
    /// vide au-dessus du panneau sur un écran sans encoche. La fenêtre est sans cadre et au
    /// niveau `.screenSaver` (voir `NotchPanelWindow`), donc au-dessus de la barre de menus et
    /// jamais recadrée sous elle.
    static func topAnchor(on screen: NSScreen) -> CGFloat {
        screen.frame.maxY
    }

    // MARK: - Cadres

    /// Le panneau proprement dit dans le cadre de la fenêtre : tout sauf la bande basse, qui
    /// revient à la capsule. C'est ce rectangle, et non le cadre entier, que la silhouette
    /// occupe et dans lequel le contenu se pose.
    static func panelRect(in bounds: CGRect) -> CGRect {
        CGRect(
            x: bounds.minX,
            y: bounds.minY + capsuleBandHeight,
            width: bounds.width,
            height: max(0, bounds.height - capsuleBandHeight)
        )
    }

    /// Cadre de la capsule : tout en bas, centrée sous le panneau.
    static func capsuleRect(in bounds: CGRect) -> CGRect {
        let width = min(NotchTabCapsuleView.width, bounds.width)
        return CGRect(
            x: bounds.midX - width / 2,
            y: bounds.minY,
            width: width,
            height: TabBarMetrics.capsuleHeight
        )
    }

    /// Cadre de la fenêtre, identique replié comme déplié : c'est la silhouette qui s'anime à
    /// l'intérieur, jamais la fenêtre, qui redimensionnée à chaque image hacherait le dépliage.
    static func windowFrame(on screen: NSScreen) -> NSRect {
        let size = expandedSize(on: screen)
        return NSRect(
            x: screen.frame.midX - size.width / 2,
            y: topAnchor(on: screen) - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// Taille de la silhouette repliée : celle de l'encoche quand il y en a une, la pastille
    /// sinon.
    static func collapsedSize(on screen: NSScreen) -> NSSize {
        notchRect(on: screen).map { NSSize(width: $0.width, height: $0.height) } ?? pillSize
    }

    /// Zone sensible qui déclenche le dépliage : la silhouette repliée, élargie de quoi
    /// l'atteindre sans viser au pixel près.
    static let hotZonePadding: CGFloat = 18

    static func hotZone(on screen: NSScreen) -> NSRect {
        let size = collapsedSize(on: screen)
        let top = topAnchor(on: screen)
        return NSRect(
            x: screen.frame.midX - size.width / 2 - hotZonePadding,
            y: top - size.height - hotZonePadding,
            width: size.width + 2 * hotZonePadding,
            height: size.height + hotZonePadding
        )
    }
}

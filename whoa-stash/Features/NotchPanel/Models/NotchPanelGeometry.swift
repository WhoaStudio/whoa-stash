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

    /// Écart entre la barre d'onglets et le contenu de l'onglet, sous elle.
    static let tabBarGap = PanelGeometry.contentSpacing

    /// Bande de la semaine, tout le contenu de l'onglet Global. Même vue que dans la bande du
    /// bord droit, donc même hauteur.
    static let weekStripHeight: CGFloat = 54

    /// Colonne de gauche de l'onglet AI : les bagues d'utilisation posées **en ligne** et non
    /// empilées, c'est tout ce qui distingue cette mise en page de celle de la bande du bord
    /// droit.
    static let ringTileSize: CGFloat = 60
    static let ringSpacing: CGFloat = 20

    /// Écart de chaque côté du filet qui sépare les deux colonnes.
    static let columnGap: CGFloat = 24
    static let dividerWidth: CGFloat = 1

    /// Colonne de droite de l'onglet AI : la carte d'utilisation détaillée, aux dimensions que
    /// `ClaudeUsagePanelView` demande pour tenir son en-tête et ses deux lignes.
    static let cardSize = NSSize(width: 320, height: 190)

    static var ringRowWidth: CGFloat {
        let count = CGFloat(SidePanelGeometry.ringCount)
        return count * ringTileSize + max(0, count - 1) * ringSpacing
    }

    /// Hauteur du contenu d'un onglet, sous la barre : celle de l'onglet le plus haut — AI, qui
    /// porte la carte —, pour que la silhouette dépliée ne change pas de taille d'un onglet à
    /// l'autre.
    static var tabContentHeight: CGFloat {
        max(weekStripHeight, cardSize.height)
    }

    /// Largeur du contenu de l'onglet le plus large — AI, avec ses deux colonnes.
    static var tabContentWidth: CGFloat {
        ringRowWidth + 2 * columnGap + dividerWidth + cardSize.width
    }

    /// Taille dépliée. La largeur est celle du plus large de ce que le panneau porte : les deux
    /// colonnes de l'onglet AI, ou la rangée d'onglets elle-même quand des intitulés longs la
    /// réclament — c'est le panneau qui s'élargit, jamais la barre qui déborde de la silhouette.
    static func expandedSize(collapsedHeight: CGFloat) -> NSSize {
        NSSize(
            width: 2 * contentInsetX + max(tabContentWidth, NotchTabBarView.minimumRowWidth),
            height: contentInsetTop(forCollapsedHeight: collapsedHeight)
                + TabBarMetrics.barHeight
                + tabBarGap
                + tabContentHeight
                + contentInsetBottom
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

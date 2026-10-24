import AppKit

/// Géométrie du panneau de l'encoche pour un écran donné : la silhouette repliée (l'encoche
/// matérielle quand il y en a une, une pastille posée sous la barre de menus sinon), la
/// silhouette dépliée, et la zone sensible qui déclenche le dépliage. Tout est exprimé en
/// coordonnées globales AppKit (origine en bas à gauche de l'écran principal, axe Y vers le haut).
///
/// Jumelle de `SidePanelGeometry`, qui reste la géométrie du panneau du bord droit : les deux
/// placements coexistent et ne partagent aucune constante, leurs silhouettes n'ayant rien en
/// commun.
enum NotchPanelGeometry {

    // MARK: - Silhouette

    /// Rayon des deux raccords **concaves** du haut, là où le panneau s'évase dans le bord
    /// auquel il est suspendu — le haut de l'écran sur un Mac à encoche, le bas de la barre de
    /// menus sinon.
    static let collapsedShoulderRadius: CGFloat = 7
    static let expandedShoulderRadius: CGFloat = 14

    /// Rayon des deux coins **convexes** du bas.
    static let collapsedBottomRadius: CGFloat = 10
    static let expandedBottomRadius: CGFloat = 28

    // MARK: - État replié

    /// Largeur retenue quand l'écran annonce une encoche sans que la largeur des deux bandes de
    /// barre de menus soit lisible — l'encoche des MacBook actuels mesure environ cela.
    static let fallbackNotchWidth: CGFloat = 190

    /// Pastille affichée sur les Macs sans encoche : assez large pour se lire comme une poignée,
    /// assez basse pour ne rien masquer de ce qui est sous la barre de menus.
    static let pillSize = NSSize(width: 160, height: 22)

    // MARK: - État déplié

    /// Marges intérieures du contenu. Le haut est généreux parce que les raccords concaves
    /// rognent la zone peinte près du bord auquel le panneau est suspendu.
    static let contentInsetX: CGFloat = 28
    static let contentInsetTop: CGFloat = 16
    static let contentInsetBottom: CGFloat = 12

    /// Écart entre la barre d'onglets et le contenu de l'onglet, sous elle.
    static let tabBarGap: CGFloat = 12

    /// Colonne de gauche : les bagues d'utilisation posées **en ligne** et non empilées, c'est
    /// tout ce qui distingue cette mise en page de celle de la bande du bord droit.
    static let ringTileSize: CGFloat = 60
    static let ringSpacing: CGFloat = 20

    /// Écart de chaque côté du filet qui sépare les deux colonnes.
    static let columnGap: CGFloat = 24
    static let dividerWidth: CGFloat = 1

    /// Colonne de droite : la carte d'utilisation détaillée, aux dimensions que
    /// `ClaudeUsagePanelView` demande pour tenir son en-tête et ses deux lignes.
    static let cardSize = NSSize(width: 320, height: 190)

    static var ringRowWidth: CGFloat {
        let count = CGFloat(SidePanelGeometry.ringCount)
        return count * ringTileSize + max(0, count - 1) * ringSpacing
    }

    /// Hauteur du contenu d'un onglet, sous la barre : c'est l'onglet Global, le plus haut, qui
    /// la fixe, pour que la silhouette dépliée ne change pas de taille d'un onglet à l'autre.
    static var tabContentHeight: CGFloat { cardSize.height }

    static var expandedSize: NSSize {
        NSSize(
            width: 2 * contentInsetX + ringRowWidth + 2 * columnGap + dividerWidth + cardSize.width,
            height: contentInsetTop
                + TabBarMetrics.barHeight
                + tabBarGap
                + tabContentHeight
                + contentInsetBottom
        )
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
        let size = expandedSize
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

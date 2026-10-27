import AppKit
import Testing

@testable import whoa_stash

/// Mise en page du panneau de l'encoche : la boîte de contenu doit être **inscrite** dans la
/// silhouette dépliée.
///
/// Le panneau est suspendu au bord du haut, donc ce sont ses flancs gauche et droit que les
/// raccords concaves rentrent de `expandedShoulderRadius` — et non son haut et son bas, comme
/// sur une bande de flanc. Prendre les marges d'une bande telles quelles, sans les retourner,
/// laissait le contenu dépasser des flancs peints de la différence entre les deux marges.
@MainActor
struct NotchPanelGeometryTests {

    /// Un écran sans encoche suffit : la silhouette dépliée ne dépend pas de l'encoche, qui ne
    /// décide que de la silhouette repliée et de la marge haute.
    private static let collapsedHeight = NotchPanelGeometry.pillSize.height

    private static func expandedPath(_ size: NSSize) -> CGPath {
        PanelGeometry.silhouette(
            in: NSRect(origin: .zero, size: size),
            anchoredTo: .top,
            shoulderRadius: NotchPanelGeometry.expandedShoulderRadius,
            farRadius: NotchPanelGeometry.expandedBottomRadius
        )
    }

    /// La boîte de contenu, telle que `NotchPanelContentView` la pose : les marges de la
    /// géométrie retranchées du cadre de la fenêtre.
    private static func contentBox(_ size: NSSize) -> NSRect {
        let inset = NotchPanelGeometry.contentInsetX
        return NSRect(
            x: inset,
            y: NotchPanelGeometry.contentInsetBottom,
            width: size.width - 2 * inset,
            height: size.height
                - NotchPanelGeometry.contentInsetTop(forCollapsedHeight: collapsedHeight)
                - NotchPanelGeometry.contentInsetBottom
        )
    }

    @Test("les quatre coins de la boîte de contenu tombent dans la silhouette dépliée")
    func contentBoxFitsInsideExpandedSilhouette() {
        let size = NotchPanelGeometry.expandedSize(collapsedHeight: Self.collapsedHeight)
        let path = Self.expandedPath(size)
        let box = Self.contentBox(size)

        for corner in [
            CGPoint(x: box.minX, y: box.minY),
            CGPoint(x: box.maxX, y: box.minY),
            CGPoint(x: box.minX, y: box.maxY),
            CGPoint(x: box.maxX, y: box.maxY),
        ] {
            #expect(path.contains(corner), "le coin \(corner) sort de la silhouette")
        }
    }

    /// Le bord du contenu ne doit pas seulement tomber dans le chemin à ses quatre coins : les
    /// deux flancs sont échantillonnés sur toute leur hauteur, puisque c'est là que les raccords
    /// concaves rognent.
    @Test("les deux flancs de la boîte de contenu restent dans la silhouette sur toute leur hauteur")
    func contentBoxSidesStayInsideExpandedSilhouette() {
        let size = NotchPanelGeometry.expandedSize(collapsedHeight: Self.collapsedHeight)
        let path = Self.expandedPath(size)
        let box = Self.contentBox(size)

        for step in 0...40 {
            let y = box.minY + box.height * CGFloat(step) / 40
            #expect(path.contains(CGPoint(x: box.minX, y: y)), "le flanc gauche sort à y = \(y)")
            #expect(path.contains(CGPoint(x: box.maxX, y: y)), "le flanc droit sort à y = \(y)")
        }
    }

    /// La marge horizontale est celle qui court **le long** du bord d'accroche, donc celle qui
    /// doit couvrir le rayon des raccords. C'est l'invariant que l'ancienne mise en page violait.
    @Test("la marge horizontale couvre le rayon des raccords concaves")
    func horizontalInsetCoversShoulderRadius() {
        #expect(NotchPanelGeometry.contentInsetX >= NotchPanelGeometry.expandedShoulderRadius)
    }

    /// La barre d'onglets est posée sur toute la largeur utile : le panneau doit donc être assez
    /// large pour la porter, intitulés compris, plutôt que de la laisser déborder.
    @Test("le panneau est assez large pour la rangée d'onglets")
    func expandedSizeHoldsTabRow() {
        let size = NotchPanelGeometry.expandedSize(collapsedHeight: Self.collapsedHeight)
        let usable = size.width - 2 * NotchPanelGeometry.contentInsetX
        #expect(usable >= NotchTabBarView.minimumRowWidth)
    }

    /// Sur un Mac à encoche, le cadre de la fenêtre part du bord haut de la dalle : le contenu
    /// doit commencer sous l'encoche, qui couvre le haut du panneau.
    @Test("la marge haute dégage l'encoche matérielle")
    func topInsetClearsTheNotch() {
        let notchHeight: CGFloat = 38
        #expect(NotchPanelGeometry.contentInsetTop(forCollapsedHeight: notchHeight) > notchHeight)
    }
}

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
            in: NotchPanelGeometry.panelRect(in: NSRect(origin: .zero, size: size)),
            anchoredTo: .top,
            shoulderRadius: NotchPanelGeometry.expandedShoulderRadius,
            farRadius: NotchPanelGeometry.expandedBottomRadius
        )
    }

    /// La boîte de contenu, telle que `NotchPanelContentView` la pose : les marges de la
    /// géométrie retranchées du **panneau**, et non du cadre de la fenêtre — celui-ci porte en
    /// plus la bande basse où flotte la capsule, où le panneau ne peint rien.
    private static func contentBox(_ size: NSSize) -> NSRect {
        let inset = NotchPanelGeometry.contentInsetX
        let panel = NotchPanelGeometry.panelRect(in: NSRect(origin: .zero, size: size))
        return NSRect(
            x: panel.minX + inset,
            y: panel.minY + NotchPanelGeometry.contentInsetBottom,
            width: panel.width - 2 * inset,
            height: panel.height
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

    /// La capsule est centrée sous le panneau : elle doit tenir dans sa largeur, sans quoi elle
    /// déborderait de la silhouette au lieu de flotter sous elle.
    @Test("le panneau est assez large pour porter la capsule")
    func expandedSizeHoldsTabCapsule() {
        let size = NotchPanelGeometry.expandedSize(collapsedHeight: Self.collapsedHeight)
        #expect(size.width >= NotchTabCapsuleView.width)
    }

    /// La bande basse appartient à la capsule : la silhouette du panneau s'arrête au-dessus, et
    /// la capsule se pose dedans sans la toucher.
    @Test("la capsule tient dans la bande basse, sous le panneau")
    func capsuleSitsBelowThePanel() {
        let size = NotchPanelGeometry.expandedSize(collapsedHeight: Self.collapsedHeight)
        let bounds = NSRect(origin: .zero, size: size)
        let capsule = NotchPanelGeometry.capsuleRect(in: bounds)
        let panel = NotchPanelGeometry.panelRect(in: bounds)

        #expect(capsule.maxY <= panel.minY)
        #expect(panel.minY - capsule.maxY == NotchPanelGeometry.capsuleGap)
        #expect(capsule.minY >= bounds.minY)
    }

    /// Sur un Mac à encoche, le cadre de la fenêtre part du bord haut de la dalle : le contenu
    /// doit commencer sous l'encoche, qui couvre le haut du panneau.
    @Test("la marge haute dégage l'encoche matérielle")
    func topInsetClearsTheNotch() {
        let notchHeight: CGFloat = 38
        #expect(NotchPanelGeometry.contentInsetTop(forCollapsedHeight: notchHeight) > notchHeight)
    }

    // MARK: - Onglet Global

    /// C'est désormais l'onglet Global qui dimensionne le panneau : la bande de la semaine, son
    /// écart, et le widget calendrier doivent tenir dans la hauteur qu'il réclame, sans quoi le
    /// widget serait rogné par le bas du corps.
    @Test("la semaine et le widget calendrier tiennent dans la hauteur de l'onglet Global")
    func globalTabHoldsWeekStripAndCalendar() {
        let stacked = NotchPanelGeometry.weekStripHeight + NotchPanelGeometry.calendarTopGap
        #expect(stacked < NotchPanelGeometry.globalTabHeight, "il ne reste rien pour le widget")

        // Ce qui revient au widget doit encore porter la grille du mois : sa ligne d'initiales et
        // ses six lignes de semaine, à une hauteur de case qui ne tasse pas les chiffres.
        let calendarHeight = NotchPanelGeometry.globalTabHeight - stacked
        #expect(
            calendarHeight >= 15 + CGFloat(MonthGridLayout.weekRowCount) * 20,
            "la grille du mois serait tassée dans \(calendarHeight) pt"
        )
    }

    /// Le panneau garde une seule taille d'un onglet à l'autre, et c'est le plus haut qui la
    /// fixe. L'invariant vaut quel que soit celui qui prend la tête.
    @Test("la hauteur de contenu couvre tous les onglets")
    func tabContentHeightCoversEveryTab() {
        #expect(NotchPanelGeometry.tabContentHeight >= NotchPanelGeometry.globalTabHeight)
        #expect(NotchPanelGeometry.tabContentHeight >= NotchPanelGeometry.cardSize.height)
        #expect(NotchPanelGeometry.tabContentHeight >= NotchPanelGeometry.weekStripHeight)
    }

    /// Les deux colonnes du widget se partagent la largeur de l'onglet : la grille du mois est
    /// calée à droite, et il doit rester de quoi écrire un agenda à gauche.
    @Test("la grille du mois laisse une colonne utile à l'agenda")
    func monthGridLeavesRoomForTheAgenda() {
        let size = NotchPanelGeometry.expandedSize(collapsedHeight: Self.collapsedHeight)
        let bodyWidth = size.width - 2 * NotchPanelGeometry.contentInsetX
        let agendaWidth = bodyWidth
            - NotchPanelGeometry.monthGridWidth
            - NotchPanelGeometry.columnGap
            - NotchPanelGeometry.dividerWidth

        #expect(agendaWidth > NotchPanelGeometry.monthGridWidth, "l'agenda porte du texte, il doit rester le plus large")
    }
}

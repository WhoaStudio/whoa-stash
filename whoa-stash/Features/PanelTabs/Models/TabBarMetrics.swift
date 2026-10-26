import CoreGraphics

/// Mesures de la barre d'onglets, partagées par les deux panneaux qui la portent : la bande du
/// bord droit et le panneau de l'encoche.
///
/// Elles vivaient dans `SidePanelGeometry` tant qu'un seul panneau avait des onglets. Les deux
/// barres doivent se ressembler trait pour trait — c'est le même objet d'interface à deux
/// endroits — donc leurs mesures ne peuvent pas être dupliquées là où elles pourraient diverger.
/// Ce qui reste propre à chaque panneau, lui, reste dans sa géométrie : où la barre se pose, et
/// ce qu'il y a dessous.
enum TabBarMetrics {

    /// Hauteur de la rangée : les onglets à gauche, l'engrenage à droite.
    static let barHeight: CGFloat = 36

    /// Hauteur de la pastille de l'onglet actif, un peu plus basse que la rangée pour que celle-ci
    /// garde de l'air au-dessus et au-dessous.
    static let pillHeight: CGFloat = 30

    /// Marges horizontales à l'intérieur d'une pastille, de part et d'autre du couple
    /// icône + intitulé.
    static let pillHorizontalPadding: CGFloat = 11

    /// Marges auxquelles la barre descend quand la rangée ne tient pas dans sa largeur : c'est
    /// la place réservée aux intitulés qui est intouchable, pas celle qui les entoure.
    static let pillMinimumHorizontalPadding: CGFloat = 4

    static let iconSize: CGFloat = 13
    static let iconLabelGap: CGFloat = 6

    /// Écart entre deux onglets. Les pastilles ne se touchent jamais, même entre deux onglets
    /// voisins tous deux larges. Il cède avant les marges des pastilles quand la rangée est à
    /// l'étroit.
    static let tabSpacing: CGFloat = 4

    /// Côté de la zone cliquable de l'engrenage, et taille de son glyphe.
    static let gearButtonSize: CGFloat = 28
    static let gearIconSize: CGFloat = 15

    /// Air entre le dernier onglet et l'engrenage : la rangée ne va jamais jusque sous lui.
    static let gearGap: CGFloat = 8
}

import AppKit

/// Géométrie commune aux panneaux de l'overlay — la bande du bord droit (`SidePanelGeometry`) et
/// le panneau de l'encoche (`NotchPanelGeometry`). Les deux placements n'ont ni le même bord
/// d'accroche ni la même silhouette, mais ils doivent se lire comme deux états d'une même
/// surface : même rayon, mêmes marges, même filet. Ces valeurs sont donc définies ici une fois,
/// et chaque géométrie s'y rapporte au lieu de les redire.
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
}

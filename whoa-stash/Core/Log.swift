import OSLog

/// Points d'entrée `OSLog` de l'app — un `Logger` par domaine, filtrable dans Console.app
/// (`subsystem:ugolin-olle.whoa-stash category:side-panel`). Remplace `print`, qui n'est pas
/// retiré en Release : les traces `.debug` ci-dessous ne coûtent rien dans un build de
/// production et n'interpolent leur message que si quelqu'un écoute réellement.
///
/// Niveaux :
/// - `.debug` : trace de flux, utile en développement uniquement.
/// - `.info`  : transition d'état qu'on veut pouvoir reconstituer après coup.
/// - `.error` : échec qui dégrade une fonctionnalité visible par l'utilisateur.
///
/// Confidentialité : dans `Logger`, l'interpolation d'une `String` est *privée* par défaut et
/// les valeurs numériques sont publiques. On garde ce défaut pour tout ce qui vient de
/// l'utilisateur (chemins et noms des applications choisies dans les Préférences — ils n'ont
/// rien à faire dans un journal lisible par d'autres processus) et on marque explicitement
/// `.public` les valeurs purement techniques dont on a besoin pour diagnostiquer : géométrie,
/// compteurs, drapeaux, codes d'erreur système.
enum Log {

    /// Doit rester aligné sur `PRODUCT_BUNDLE_IDENTIFIER`. `nonisolated`, comme les `Logger`
    /// ci-dessous : le module est compilé avec `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, qui
    /// isolerait sinon ces constantes sur le main actor et interdirait de journaliser depuis un
    /// contexte non isolé (le callback C de l'`AXObserver`, par exemple).
    nonisolated private static let subsystem = "ugolin-olle.whoa-stash"

    /// Overlay de luminosité et pilotage de l'écran.
    nonisolated static let brightness = Logger(subsystem: subsystem, category: "brightness")

    /// Menu bar et fenêtre de Préférences.
    nonisolated static let settings = Logger(subsystem: subsystem, category: "settings")

    /// Panneau latéral et récupération de l'utilisation Claude.
    nonisolated static let sidePanel = Logger(subsystem: subsystem, category: "side-panel")

    /// Widget calendrier : droit d'accès et lecture des événements.
    nonisolated static let calendar = Logger(subsystem: subsystem, category: "calendar")

    /// Onglet Mirror : démarrage et arrêt de la caméra.
    nonisolated static let camera = Logger(subsystem: subsystem, category: "camera")

    /// Vue « Now Playing » : flux MediaRemote et commandes de lecture.
    nonisolated static let nowPlaying = Logger(subsystem: subsystem, category: "now-playing")

    /// Historique du presse-papiers : surveillance, stockage et copie en retour.
    nonisolated static let knock = Logger(subsystem: subsystem, category: "knock")
    nonisolated static let clipboard = Logger(subsystem: subsystem, category: "clipboard")
}

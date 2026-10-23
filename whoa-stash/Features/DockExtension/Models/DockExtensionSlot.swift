/// Un emplacement de l'extension du Dock : `appPath` est le chemin du `.app` choisi, ou `nil`
/// si l'emplacement est vide (il n'est alors pas rendu — pas de case translucide vide).
struct DockExtensionSlot: Codable, Identifiable, Equatable, Sendable {
    let index: Int
    var appPath: String?

    var id: Int { index }
}

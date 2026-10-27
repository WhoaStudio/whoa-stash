import Foundation
import OSLog

/// Les fichiers posés dans l'onglet Tray, et leur persistance.
///
/// Le bac vit **hors** de la vue : le panneau de l'encoche se replie, se déplie et change
/// d'onglet sans arrêt, et ce qu'on y a déposé ne doit pas disparaître avec la vue qui
/// l'affichait. `FileTrayView` n'en est plus qu'une lecture.
///
/// Rien n'est copié ni déplacé sur le disque : on ne garde que des *signets* (`URL`
/// bookmarkData), qui suivent un fichier renommé ou déplacé — un simple chemin ne le ferait pas.
/// Le fichier effacé entre deux lancements laisse un signet qui ne se résout plus : il est
/// retiré en silence au chargement, plutôt que de laisser une ligne qui ne mène nulle part.
///
/// L'app n'est pas en bac à sable (`ENABLE_APP_SANDBOX = NO`), donc pas de signet à portée
/// restreinte ni de `startAccessingSecurityScopedResource` à tenir ouvert.
@MainActor
final class FileShelfStore {

    static let shared = FileShelfStore()

    /// Émise après chaque ajout ou retrait, y compris celui qui vide le bac. Les vues
    /// s'abonnent plutôt que d'être tenues par le store : il y a une `FileTrayView` par écran,
    /// et elles vont et viennent avec les fenêtres.
    static let didChangeNotification = Notification.Name("FileShelfStore.didChange")

    private static let defaultsKey = "com.whoastudio.whoa-stash.fileShelf"

    /// Au-delà, les derniers déposés chassent les premiers : la zone n'a de place que pour
    /// quelques lignes et ne défile pas encore. C'est donc bien le bac qui est borné, pas son
    /// affichage.
    static let capacity = 4

    /// Fichiers retenus, dans l'ordre où ils ont été déposés — le dernier en fin de liste.
    private(set) var urls: [URL] = []

    /// Vrai le temps qu'un fichier soit glissé *hors* du bac. Le panneau de l'encoche se replie
    /// dès que le curseur le quitte : `NotchPanelController` gèle ce suivi tant que ce drapeau
    /// est levé, sans quoi le bac se refermerait sous la main qui en sort un fichier.
    var isDraggingOut = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        urls = Self.load(from: defaults)
    }

    var isEmpty: Bool { urls.isEmpty }

    /// Ajoute des fichiers en fin de liste. Un fichier déjà présent ne fait pas deux lignes :
    /// il remonte simplement là où l'utilisateur vient de le poser.
    func add(_ added: [URL]) {
        guard !added.isEmpty else { return }
        urls.removeAll { added.contains($0) }
        urls.append(contentsOf: added)
        if urls.count > Self.capacity {
            urls.removeFirst(urls.count - Self.capacity)
        }
        commit()
    }

    /// Retire un fichier du bac — appelé quand un glisser vers le Finder ou une autre app a
    /// abouti, jamais quand il a été annulé.
    func remove(_ url: URL) {
        guard urls.contains(url) else { return }
        urls.removeAll { $0 == url }
        commit()
    }

    private func commit() {
        persist()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    // MARK: - Persistance

    private func persist() {
        let bookmarks = urls.compactMap { url -> Data? in
            do {
                return try url.bookmarkData()
            } catch {
                Log.sidePanel.error("File shelf bookmark failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        defaults.set(bookmarks, forKey: Self.defaultsKey)
    }

    /// Résout les signets du lancement précédent et laisse tomber ceux dont le fichier n'est
    /// plus là. Un signet « périmé » (`isStale`) désigne un fichier qui a bougé : il se résout
    /// quand même, et la prochaine écriture le remplacera par un signet à jour.
    private static func load(from defaults: UserDefaults) -> [URL] {
        guard let bookmarks = defaults.array(forKey: defaultsKey) as? [Data] else { return [] }

        return bookmarks.compactMap { data in
            var isStale = false
            guard
                let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale),
                FileManager.default.fileExists(atPath: url.path)
            else { return nil }
            return url
        }
    }
}

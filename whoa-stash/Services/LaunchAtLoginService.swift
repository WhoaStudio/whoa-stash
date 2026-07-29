import Foundation
import ServiceManagement

/// Enregistre ou désenregistre l'app comme élément de lancement au démarrage de session.
/// Isolé dans un service dédié pour que `AppSettingsStore` reste une simple persistance,
/// sans effet de bord système dans son `didSet`.
final class LaunchAtLoginService {

    static let shared = LaunchAtLoginService()

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            print("Préférences: lancement au démarrage → \(enabled ? "activé" : "désactivé")")
        } catch {
            print("Préférences: échec de la configuration du lancement au démarrage — \(error.localizedDescription)")
        }
    }
}

import AppKit

/// Abstraction du lancement d'application — permet d'injecter un lanceur factice en test,
/// au même titre que `BrightnessControlling`/`VolumeControlling`.
protocol AppLaunching {
    func launch(at url: URL, completion: @escaping @Sendable (Error?) -> Void)
}

/// Lance une application via `NSWorkspace`, ou l'active si elle tourne déjà (comportement
/// par défaut d'`openApplication`).
final class AppLauncherService: AppLaunching {

    static let shared = AppLauncherService()

    func launch(at url: URL, completion: @escaping @Sendable (Error?) -> Void) {
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            completion(error)
        }
    }
}

import AppKit
import Combine

/// Expose la liste des slots résolus et l'activation d'une app, avec un callback simple pour
/// la vue AppKit (même esprit que `BrightnessViewModel` : pas de Combine côté vue).
@MainActor
final class DockExtensionViewModel {

    private(set) var resolvedSlots: [ResolvedDockSlot] = []

    var onSlotsChanged: (() -> Void)?

    private let launcher: AppLaunching
    private var cancellable: AnyCancellable?

    init(preferences: SettingsStorage = .shared, launcher: AppLaunching = AppLauncherService.shared) {
        self.launcher = launcher
        cancellable = preferences.$settings
            .map(\.dock.slots)
            .removeDuplicates()
            .sink { [weak self] slots in
                self?.resolve(slots)
            }
    }

    /// Lance l'app, ou l'active si elle tourne déjà (comportement par défaut d'`openApplication`).
    func activate(_ slot: ResolvedDockSlot) {
        let name = slot.name
        launcher.launch(at: slot.bundleURL) { error in
            if let error {
                print("DockExtension: échec du lancement de \(name) — \(error.localizedDescription)")
            }
        }
    }

    private func resolve(_ slots: [DockExtensionSlot]) {
        print("[DockExt][ViewModel] resolve() — préférences brutes: \(slots.map { "\($0.index): \($0.appPath ?? "vide")" })")
        resolvedSlots = slots.compactMap { slot in
            guard let path = slot.appPath else { return nil }
            guard FileManager.default.fileExists(atPath: path) else {
                print("[DockExt][ViewModel] ⛔️ slot \(slot.index): chemin introuvable sur le disque: \(path)")
                return nil
            }
            return ResolvedDockSlot(
                index: slot.index,
                bundleURL: URL(fileURLWithPath: path),
                icon: NSWorkspace.shared.icon(forFile: path),
                name: FileManager.default.displayName(atPath: path)
            )
        }
        print("[DockExt][ViewModel] resolve() → \(resolvedSlots.count) slot(s) résolu(s): \(resolvedSlots.map { $0.name })")
        onSlotsChanged?()
    }
}

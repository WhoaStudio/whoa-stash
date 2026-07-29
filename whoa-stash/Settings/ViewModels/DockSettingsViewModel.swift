import AppKit
import Combine

/// Expose la section "Dock Extension" à sa vue : les 5 emplacements et leur activation
/// globale, sans que la vue touche `SettingsStorage` ou `AppPickerService` directement.
@MainActor
final class DockSettingsViewModel: ObservableObject {

    private let storage: SettingsStorage
    private let appPicker: AppPickerService
    private var cancellable: AnyCancellable?

    @Published private(set) var settings: DockExtensionSettings

    init(storage: SettingsStorage = .shared, appPicker: AppPickerService = .shared) {
        self.storage = storage
        self.appPicker = appPicker
        self.settings = storage.settings.dock

        cancellable = storage.$settings
            .map(\.dock)
            .removeDuplicates()
            .sink { [weak self] in self?.settings = $0 }
    }

    func setEnabled(_ enabled: Bool) {
        storage.settings.dock.isEnabled = enabled
    }

    func setSide(_ side: EdgePosition) {
        storage.settings.dock.side = side
    }

    func chooseApp(for slot: DockExtensionSlot) {
        guard let path = appPicker.chooseApplication() else { return }
        setPath(path, forSlotAt: slot.index)
    }

    func clearApp(for slot: DockExtensionSlot) {
        setPath(nil, forSlotAt: slot.index)
    }

    func icon(for slot: DockExtensionSlot) -> NSImage? {
        guard let path = slot.appPath else { return nil }
        return NSWorkspace.shared.icon(forFile: path)
    }

    func name(for slot: DockExtensionSlot) -> String {
        guard let path = slot.appPath else { return "Empty" }
        return FileManager.default.displayName(atPath: path)
    }

    private func setPath(_ path: String?, forSlotAt index: Int) {
        guard storage.settings.dock.slots.indices.contains(index) else { return }
        storage.settings.dock.slots[index].appPath = path
    }
}

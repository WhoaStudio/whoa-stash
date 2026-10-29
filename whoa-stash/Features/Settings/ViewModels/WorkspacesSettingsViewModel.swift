import Combine
import Foundation

/// Expose la section "Workspaces" à sa vue : la liste des espaces et l'espace en cours d'édition.
@MainActor
final class WorkspacesSettingsViewModel: ObservableObject {

    private let storage: SettingsStorage
    private var cancellable: AnyCancellable?

    @Published private(set) var settings: DockSettings
    /// L'espace affiché dans le formulaire — pas forcément l'espace actif du dock.
    @Published var selectedID: String?

    init(storage: SettingsStorage = .shared) {
        self.storage = storage
        self.settings = storage.settings.dock
        self.selectedID = storage.settings.dock.activeWorkspaceID ?? storage.settings.dock.workspaces.first?.id

        cancellable = storage.$settings
            .map(\.dock)
            .removeDuplicates()
            .sink { [weak self] dock in
                guard let self else { return }
                self.settings = dock
                if let id = self.selectedID, !dock.workspaces.contains(where: { $0.id == id }) {
                    self.selectedID = dock.workspaces.first?.id
                }
            }
    }

    var selected: DockWorkspace? {
        selectedID.flatMap { id in settings.workspaces.first { $0.id == id } }
    }

    func create() {
        let workspace = DockWorkspace(name: "Workspace \(settings.workspaces.count + 1)")
        storage.settings.dock.workspaces.append(workspace)
        selectedID = workspace.id
    }

    func deleteSelected() {
        guard let id = selectedID else { return }
        storage.settings.dock.workspaces.removeAll { $0.id == id }
        if storage.settings.dock.activeWorkspaceID == id { storage.settings.dock.activeWorkspaceID = nil }
    }

    func update(_ change: (inout DockWorkspace) -> Void) {
        guard let id = selectedID, let index = storage.settings.dock.workspaces.firstIndex(where: { $0.id == id }) else { return }
        change(&storage.settings.dock.workspaces[index])
    }

    func setApp(_ app: DockPinnedApp, selected: Bool) {
        update { workspace in
            let present = workspace.apps.contains { $0.bundleID == app.bundleID }
            if selected && !present { workspace.apps.append(app) }
            if !selected { workspace.apps.removeAll { $0.bundleID == app.bundleID } }
        }
    }

    /// Met l'appli à `index` du dock de l'espace — la déplace si elle y est déjà, l'ajoute sinon.
    func placeApp(_ app: DockPinnedApp, at index: Int) {
        update { $0.apps.place(app, at: index) }
    }

    func setActive(_ active: Bool) {
        guard let id = selectedID else { return }
        storage.settings.dock.activeWorkspaceID = active ? id : (storage.settings.dock.activeWorkspaceID == id ? nil : storage.settings.dock.activeWorkspaceID)
    }
}

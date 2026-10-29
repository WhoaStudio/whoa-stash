import Foundation

/// Garantit au moins un espace de travail — « Building », rempli des applis épinglées du Dock
/// macOS — et un espace actif : le groupe de gauche du dock montre toujours où l'on est.
@MainActor
enum WorkspaceSeeder {
    static func seedIfNeeded(_ storage: SettingsStorage) {
        if storage.settings.dock.workspaces.isEmpty {
            storage.settings.dock.workspaces = [DockWorkspace(
                name: "Building", symbol: "hammer.fill", colorHex: "#2E70D1", apps: storage.settings.dock.pinnedApps)]
        }
        if storage.settings.dock.activeWorkspace == nil {
            storage.settings.dock.activeWorkspaceID = storage.settings.dock.workspaces.first?.id
        }
    }
}

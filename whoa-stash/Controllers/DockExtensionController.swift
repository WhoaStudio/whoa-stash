import AppKit
import Combine
import OSLog

/// Relie le suivi du Dock (`DockGeometryProvider`), les icônes configurées
/// (`DockExtensionViewModel`) et la fenêtre flottante (`DockExtensionWindow`) : positionne,
/// révèle et masque l'extension en fonction de la géométrie réelle du Dock, et reconstruit les
/// icônes quand les préférences changent. Démarre/arrête le suivi selon
/// `settings.dock.isEnabled`.
@MainActor
final class DockExtensionController {

    private let geometryProvider = DockGeometryProvider()
    private let window = DockExtensionWindow()
    private let viewModel = DockExtensionViewModel()

    private var lastGeometry: DockGeometry?
    private var isEnabled = false
    private var side: EdgePosition = .right
    private var cancellable: AnyCancellable?
    private var sideCancellable: AnyCancellable?

    func activate() {
        Log.dockExtension.debug("controller: activate()")

        window.onIconClicked = { [weak self] slot in
            Log.dockExtension.debug("controller: icône cliquée: \(slot.name)")
            self?.viewModel.activate(slot)
        }

        viewModel.onSlotsChanged = { [weak self] in
            Log.dockExtension.debug("controller: viewModel.onSlotsChanged")
            self?.applySlots()
        }
        applySlots()

        geometryProvider.onChange = { [weak self] geometry in
            self?.handleGeometryChange(geometry)
        }

        cancellable = SettingsStorage.shared.$settings
            .map(\.dock.isEnabled)
            .removeDuplicates()
            .sink { [weak self] enabled in
                self?.setEnabled(enabled)
            }

        sideCancellable = SettingsStorage.shared.$settings
            .map(\.dock.side)
            .removeDuplicates()
            .sink { [weak self] side in
                self?.setSide(side)
            }
    }

    private func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled

        if enabled {
            geometryProvider.start()
        } else {
            geometryProvider.stop()
            lastGeometry = nil
            window.hide()
        }
    }

    private func setSide(_ newSide: EdgePosition) {
        guard side != newSide else { return }
        Log.dockExtension.debug("controller: setSide(\(newSide.rawValue, privacy: .public))")
        side = newSide

        guard isEnabled, let geometry = lastGeometry, !viewModel.resolvedSlots.isEmpty else { return }
        window.reveal(against: geometry, side: side)
    }

    private func applySlots() {
        let tileSize = lastGeometry?.tileSize ?? 64
        Log.dockExtension.debug("controller: applySlots() — \(self.viewModel.resolvedSlots.count, privacy: .public) slot(s) résolu(s): \(self.viewModel.resolvedSlots.map { $0.name }.description), tileSize=\(tileSize, privacy: .public), lastGeometry=\(self.lastGeometry != nil, privacy: .public)")
        window.setSlots(viewModel.resolvedSlots, tileSize: tileSize)

        guard isEnabled, let geometry = lastGeometry else {
            Log.dockExtension.debug("controller: applySlots() — pas de géométrie connue ou extension désactivée, pas d'affichage")
            return
        }
        if viewModel.resolvedSlots.isEmpty {
            Log.dockExtension.debug("controller: applySlots() — aucun slot configuré → hide()")
            window.hide()
        } else {
            Log.dockExtension.debug("controller: applySlots() — reveal() avec la géométrie connue")
            window.reveal(against: geometry, side: side)
        }
    }

    private func handleGeometryChange(_ geometry: DockGeometry?) {
        Log.dockExtension.debug("controller: handleGeometryChange(geometry=\(geometry != nil, privacy: .public)) — slots configurés=\(self.viewModel.resolvedSlots.count, privacy: .public)")
        lastGeometry = geometry

        guard let geometry, !viewModel.resolvedSlots.isEmpty else {
            Log.dockExtension.debug("controller: → hide() (geometry nil ou aucun slot configuré)")
            window.hide()
            return
        }

        Log.dockExtension.debug("controller: → reveal(against: \(String(describing: geometry.frame), privacy: .public), side: \(self.side.rawValue, privacy: .public))")
        window.reveal(against: geometry, side: side)
    }
}

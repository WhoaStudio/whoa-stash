import AppKit
import Combine

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
        print("[DockExt][Controller] activate()")

        window.onIconClicked = { [weak self] slot in
            print("[DockExt][Controller] icône cliquée: \(slot.name)")
            self?.viewModel.activate(slot)
        }

        viewModel.onSlotsChanged = { [weak self] in
            print("[DockExt][Controller] viewModel.onSlotsChanged")
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
        print("[DockExt][Controller] setSide(\(newSide))")
        side = newSide

        guard isEnabled, let geometry = lastGeometry, !viewModel.resolvedSlots.isEmpty else { return }
        window.reveal(against: geometry, side: side)
    }

    private func applySlots() {
        let tileSize = lastGeometry?.tileSize ?? 64
        print("[DockExt][Controller] applySlots() — \(viewModel.resolvedSlots.count) slot(s) résolu(s): \(viewModel.resolvedSlots.map { $0.name }), tileSize=\(tileSize), lastGeometry=\(lastGeometry != nil)")
        window.setSlots(viewModel.resolvedSlots, tileSize: tileSize)

        guard isEnabled, let geometry = lastGeometry else {
            print("[DockExt][Controller] applySlots(): pas de géométrie connue ou extension désactivée, pas d'affichage")
            return
        }
        if viewModel.resolvedSlots.isEmpty {
            print("[DockExt][Controller] applySlots(): aucun slot configuré → hide()")
            window.hide()
        } else {
            print("[DockExt][Controller] applySlots(): reveal() avec la géométrie connue")
            window.reveal(against: geometry, side: side)
        }
    }

    private func handleGeometryChange(_ geometry: DockGeometry?) {
        print("[DockExt][Controller] handleGeometryChange(geometry=\(geometry != nil)) — slots configurés=\(viewModel.resolvedSlots.count)")
        lastGeometry = geometry

        guard let geometry, !viewModel.resolvedSlots.isEmpty else {
            print("[DockExt][Controller] → hide() (geometry nil ou aucun slot configuré)")
            window.hide()
            return
        }

        print("[DockExt][Controller] → reveal(against: \(geometry.frame), side: \(side))")
        window.reveal(against: geometry, side: side)
    }
}

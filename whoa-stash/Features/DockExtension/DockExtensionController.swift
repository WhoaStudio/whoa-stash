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

    /// Survol de la bague d'utilisation Claude, avec son cadre en coordonnées écran — relayé par
    /// `AppDelegate` au panneau latéral, que ce contrôleur n'a pas à connaître.
    var onUsageRingHoverChanged: ((Bool, NSRect) -> Void)?

    private let geometryProvider = DockGeometryProvider()
    private let window = DockExtensionWindow()
    private let viewModel: DockExtensionViewModel
    private let storage: SettingsStorage

    private var lastGeometry: DockGeometry?
    private var isEnabled = false
    private var side: EdgePosition = .right
    private var cancellable: AnyCancellable?
    private var sideCancellable: AnyCancellable?

    init(storage: SettingsStorage = .shared) {
        self.storage = storage
        viewModel = DockExtensionViewModel(preferences: storage)
    }

    func activate() {
        Log.dockExtension.debug("controller: activate()")

        window.onIconClicked = { [weak self] slot in
            Log.dockExtension.debug("controller: icône cliquée: \(slot.name)")
            self?.viewModel.activate(slot)
        }

        window.onUsageRingHoverChanged = { [weak self] hovering, rect in
            self?.onUsageRingHoverChanged?(hovering, rect)
        }

        viewModel.onSlotsChanged = { [weak self] in
            Log.dockExtension.debug("controller: viewModel.onSlotsChanged")
            self?.applySlots()
        }
        applySlots()

        geometryProvider.onChange = { [weak self] geometry in
            self?.handleGeometryChange(geometry)
        }

        cancellable = storage.$settings
            .map(\.dock.isEnabled)
            .removeDuplicates()
            .sink { [weak self] enabled in
                self?.setEnabled(enabled)
            }

        sideCancellable = storage.$settings
            .map(\.dock.side)
            .removeDuplicates()
            .sink { [weak self] side in
                self?.setSide(side)
            }
    }

    func apply(usageState: ClaudeUsageState) {
        window.apply(usageState: usageState)
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

        guard isEnabled, let geometry = lastGeometry else { return }
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
        // Plus de `hide()` quand aucune app n'est configurée : la bague d'utilisation Claude est
        // une case permanente, donc l'extension a toujours quelque chose à montrer.
        Log.dockExtension.debug("controller: applySlots() — reveal() avec la géométrie connue")
        window.reveal(against: geometry, side: side)
    }

    private func handleGeometryChange(_ geometry: DockGeometry?) {
        Log.dockExtension.debug("controller: handleGeometryChange(geometry=\(geometry != nil, privacy: .public)) — slots configurés=\(self.viewModel.resolvedSlots.count, privacy: .public)")
        lastGeometry = geometry

        guard let geometry else {
            Log.dockExtension.debug("controller: → hide() (plus de géométrie de Dock connue)")
            window.hide()
            return
        }

        Log.dockExtension.debug("controller: → reveal(against: \(String(describing: geometry.frame), privacy: .public), side: \(self.side.rawValue, privacy: .public))")
        window.reveal(against: geometry, side: side)
    }
}

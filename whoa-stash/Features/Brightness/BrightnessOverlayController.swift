import AppKit
import Combine

/// Fenêtre flottante (NSPanel) qui héberge le widget de luminosité.
/// Sans titre, transparente, toujours au-dessus, ne prend jamais le focus.
///
/// Apparaît quand le curseur atteint le bord configuré de l'écran, reste affichée tant que
/// le curseur est au-dessus d'elle (ou que l'utilisateur scrolle), et se referme peu après
/// que le curseur l'a quittée — comme un contrôle qui "suit" l'utilisateur plutôt qu'un
/// widget qui s'impose pendant deux secondes fixes. Chaque aspect visible (taille, position,
/// délai de fermeture, intensité du glow, affichage du pourcentage) suit `Brightness` dans
/// les Préférences en direct.
@MainActor
final class BrightnessOverlayController {

    private let panel: NSPanel
    private let containerView: BrightnessView
    private let viewModel: BrightnessViewModel
    private let mouseMonitor = GlobalMouseMonitor()
    private var closeWorkItem: DispatchWorkItem?
    private var settingsCancellable: AnyCancellable?

    private var panelSize: NSSize
    private var closeDelay: TimeInterval
    private var glowIntensity: Double
    private var showPercentage: Bool
    private var widgetPosition: EdgePosition
    private var isEnabled = false

    private let edgeThreshold: CGFloat = 2
    private let hideAnimationDuration: TimeInterval = 0.45

    /// `storage` n'est lu qu'ici : au-delà de l'init, l'état courant arrive par
    /// `settingsCancellable`, pas par une relecture du stockage.
    init(controller: BrightnessControlling, storage: SettingsStorage = .shared) {
        let brightness = storage.settings.brightness
        panelSize = brightness.widgetSize.panelSize
        closeDelay = brightness.autoHideDelay
        glowIntensity = brightness.glowIntensity
        showPercentage = brightness.showPercentage
        widgetPosition = brightness.widgetPosition

        // Le feedback partage le même `storage` que le view model : tout le graphe de l'overlay
        // lit donc une seule et même source de préférences.
        viewModel = BrightnessViewModel(
            controller: controller,
            feedback: SystemBrightnessFeedback(storage: storage),
            storage: storage
        )

        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = true
        // Sans ça, le panel se cache dès que whoa-stash (app sans fenêtre, menu bar only)
        // n'est plus "active", ce qui arrive en permanence puisqu'elle ne prend jamais le focus.
        panel.hidesOnDeactivate = false
        panel.appearance = storage.settings.general.appearanceMode.nsAppearance

        let initialPalette = OverlayPalette.resolved(for: panel.effectiveAppearance).scalingGlow(by: glowIntensity)
        containerView = BrightnessView(tickCount: BrightnessViewModel.tickCount, initialPalette: initialPalette)
        containerView.frame = NSRect(origin: .zero, size: panelSize)
        panel.contentView = containerView

        containerView.onScroll = { [weak self] delta in self?.handleScroll(delta) }
        containerView.sunButton.onTap = { [weak self] in self?.handleSunTap() }

        mouseMonitor.onMove = { [weak self] location in self?.handlePointerMove(location) }

        settingsCancellable = storage.$settings
            .sink { [weak self] settings in
                self?.apply(general: settings.general, brightness: settings.brightness)
            }
    }

    func activate() {
        containerView.updateBrightness(activeTickCount: viewModel.activeTickCount, animated: false)
    }

    private func apply(general: GeneralSettings, brightness: BrightnessSettings) {
        panel.appearance = general.appearanceMode.nsAppearance

        closeDelay = brightness.autoHideDelay
        showPercentage = brightness.showPercentage
        widgetPosition = brightness.widgetPosition

        if glowIntensity != brightness.glowIntensity {
            glowIntensity = brightness.glowIntensity
            containerView.applyPalette(OverlayPalette.resolved(for: panel.effectiveAppearance).scalingGlow(by: glowIntensity))
        }

        if panelSize != brightness.widgetSize.panelSize {
            panelSize = brightness.widgetSize.panelSize
            resizePanel()
        }

        setEnabled(brightness.enableOverlay)
    }

    private func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled

        if enabled {
            mouseMonitor.start()
        } else {
            mouseMonitor.stop()
            dismiss()
        }
    }

    private func resizePanel() {
        var frame = panel.frame
        frame.size = panelSize
        panel.setFrame(frame, display: true)
        containerView.frame = NSRect(origin: .zero, size: panelSize)

        if viewModel.isVisible, let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) {
            position(on: screen)
        }
    }

    private func handlePointerMove(_ location: NSPoint) {
        if viewModel.isVisible {
            if panel.frame.contains(location) {
                cancelClose()
            } else {
                scheduleClose()
            }
        } else if isAtEdge(location) {
            reveal()
        }
    }

    private func isAtEdge(_ location: NSPoint) -> Bool {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) else { return false }
        switch widgetPosition {
        case .left: return location.x <= screen.frame.minX + edgeThreshold
        case .right: return location.x >= screen.frame.maxX - edgeThreshold
        }
    }

    private func reveal() {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) else { return }
        position(on: screen)

        // La luminosité a pu changer pendant que le widget était fermé (touches clavier,
        // Réglages Système...) : on se resynchronise avant d'afficher, sans jouer de son/tick.
        viewModel.syncWithSystem()
        containerView.updateBrightness(activeTickCount: viewModel.activeTickCount, animated: false)

        if !panel.isVisible {
            panel.alphaValue = 1
            panel.orderFrontRegardless()
        }
        panel.ignoresMouseEvents = false
        viewModel.setVisible(true)
        containerView.setVisible(true)
        cancelClose()
    }

    private func position(on screen: NSScreen) {
        // Le panel démarre pile au bord de l'écran : le curseur qui déclenche l'apparition
        // se trouve donc déjà "au-dessus" du widget, pas d'à-coup au premier survol.
        let x = widgetPosition == .right ? screen.frame.maxX - panelSize.width : screen.frame.minX
        let y = screen.frame.midY - panelSize.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func handleScroll(_ deltaY: CGFloat) {
        guard viewModel.isVisible else { return }
        viewModel.adjust(byScrollDelta: deltaY)
        containerView.updateBrightness(activeTickCount: viewModel.activeTickCount, animated: true)
        if showPercentage {
            containerView.showPercent(viewModel.percent)
        }
        cancelClose()
    }

    private func handleSunTap() {
        viewModel.setBrightness(1.0)
        containerView.updateBrightness(activeTickCount: viewModel.activeTickCount, animated: true)
        cancelClose()
    }

    private func scheduleClose() {
        guard closeWorkItem == nil else { return }
        let item = DispatchWorkItem { [weak self] in self?.dismiss() }
        closeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + closeDelay, execute: item)
    }

    private func cancelClose() {
        closeWorkItem?.cancel()
        closeWorkItem = nil
    }

    private func dismiss() {
        cancelClose()
        guard viewModel.isVisible else { return }
        viewModel.setVisible(false)
        containerView.setVisible(false)
        panel.ignoresMouseEvents = true

        DispatchQueue.main.asyncAfter(deadline: .now() + hideAnimationDuration) { [weak self] in
            guard let self, !self.viewModel.isVisible else { return }
            self.panel.orderOut(nil)
        }
    }
}

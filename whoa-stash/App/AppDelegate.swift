import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Racine de composition : une seule instance de `SettingsStorage` traverse toute l'app.
    /// C'est volontairement `.shared` et non une instance neuve — `SettingsWindowController`
    /// lit encore le singleton, et deux instances distinctes scinderaient silencieusement
    /// l'état des préférences entre la fenêtre de réglages et les widgets.
    private let settings = SettingsStorage.shared

    private var statusBarController: StatusBarController?
    private var edgeSliderController: EdgeSliderController?
    private var brightnessOverlayController: BrightnessOverlayController?
    private var dockExtensionController: DockExtensionController?
    private var sidePanelController: SidePanelController?
    private var claudeUsageViewModel: ClaudeUsageViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Icône dans la menu bar (en haut à droite de l'écran)
        statusBarController = StatusBarController()

        // Fenêtre flottante invisible qui gère le slider sur le bord de l'écran
        edgeSliderController = EdgeSliderController(storage: settings)
        edgeSliderController?.activate()

        // Overlay de luminosité sur le bord gauche de l'écran.
        // Remplacer par `FakeBrightnessService()` pour développer sans piloter l'écran réel.
        brightnessOverlayController = BrightnessOverlayController(
            controller: SystemBrightnessService(),
            storage: settings
        )
        brightnessOverlayController?.activate()

        // Extension du Dock : panneau flottant collé au Dock système, icônes configurables.
        dockExtensionController = DockExtensionController(storage: settings)
        dockExtensionController?.activate()

        // Panneau latéral : glisse depuis le bord droit quand le curseur entre dans la zone
        // sensible du coin supérieur droit, sur chacun des écrans connectés.
        sidePanelController = SidePanelController()
        sidePanelController?.activate()

        // Utilisation Claude : un seul modèle de vue alimente la bague du Dock et le panneau
        // latéral, pour qu'ils montrent le même instantané et qu'un seul appel réseau les serve.
        // `--claude-usage=73,7` substitue des valeurs fixes à la vraie source (voir
        // `MockClaudeUsageProvider`), pour développer et vérifier sans réseau ni trousseau.
        let usageProvider: ClaudeUsageProviding = MockClaudeUsageProvider.fromLaunchArguments() ?? ClaudeUsageService()
        let usageViewModel = ClaudeUsageViewModel(provider: usageProvider)
        claudeUsageViewModel = usageViewModel

        usageViewModel.onStateChanged = { [weak self] in
            guard let self, let state = self.claudeUsageViewModel?.state else { return }
            self.dockExtensionController?.apply(usageState: state)
            self.sidePanelController?.apply(usageState: state)
        }

        dockExtensionController?.onUsageRingClicked = { [weak self] in
            // Rafraîchissement opportuniste : le panneau s'ouvre tout de suite avec le dernier
            // instantané connu, et se met à jour dès que la requête revient.
            self?.claudeUsageViewModel?.refresh()
            self?.sidePanelController?.togglePinnedReveal()
        }

        usageViewModel.activate()

        // Ouvre le panneau d'utilisation sans passer par le survol du coin ni le clic sur la
        // bague — c'est ce qui rend la carte vérifiable sur capture d'écran, au même titre que
        // `--show-settings` pour les Préférences.
        if CommandLine.arguments.contains("--show-usage-panel") {
            sidePanelController?.togglePinnedReveal()
        }

        if CommandLine.arguments.contains("--dark") {
            settings.settings.general.appearanceMode = .dark
        }

        if let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--show-settings") }) {
            let categoryRaw = arg.split(separator: "=").last.map(String.init)
            let category = categoryRaw.flatMap { SettingsCategory(rawValue: $0) } ?? .general
            SettingsWindowController.shared.show(category)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Nettoyage si besoin
    }
}

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
    private var sidePanelController: SidePanelController?
    private var notchPanelController: NotchPanelController?
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

        // Panneau latéral : glisse depuis le bord droit quand le curseur entre dans la zone
        // sensible du coin supérieur droit, sur chacun des écrans connectés.
        sidePanelController = SidePanelController(storage: settings)
        sidePanelController?.activate()

        // Panneau de l'encoche : suspendu au haut de l'écran, replié sur l'encoche matérielle
        // (ou sur une pastille quand il n'y en a pas), il se déplie au survol. Placement
        // indépendant de la bande du bord droit, que le réglage Général permet de couper.
        notchPanelController = NotchPanelController(storage: settings)
        notchPanelController?.activate()

        // Utilisation Claude : le modèle de vue alimente la bande latérale, et un seul appel
        // réseau la sert.
        // `--claude-usage=73,7` substitue des valeurs fixes à la vraie source (voir
        // `MockClaudeUsageProvider`), pour développer et vérifier sans réseau ni trousseau.
        let usageProvider: ClaudeUsageProviding = MockClaudeUsageProvider.fromLaunchArguments() ?? ClaudeUsageService()
        let usageViewModel = ClaudeUsageViewModel(provider: usageProvider)
        claudeUsageViewModel = usageViewModel

        usageViewModel.onStateChanged = { [weak self] in
            guard let self, let state = self.claudeUsageViewModel?.state else { return }
            self.sidePanelController?.apply(usageState: state)
            self.notchPanelController?.apply(usageState: state)
        }

        usageViewModel.activate()

        // Ouvre la bande sans passer par le survol du coin — c'est ce qui la rend vérifiable
        // sur capture d'écran, au même titre que `--show-settings` pour les Préférences.
        if CommandLine.arguments.contains("--show-usage-panel") {
            sidePanelController?.togglePinnedReveal()
        }

        // Même usage pour le panneau de l'encoche : le déplier sans passer par le survol est ce
        // qui le rend vérifiable sur capture d'écran.
        if CommandLine.arguments.contains("--show-notch-panel") {
            notchPanelController?.togglePinnedReveal()
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

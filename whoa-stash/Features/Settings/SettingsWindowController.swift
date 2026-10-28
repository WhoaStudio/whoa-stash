import AppKit
import Combine
import OSLog

/// Gère la fenêtre de Préférences : instance unique, ramenée au premier plan à chaque
/// ouverture. Compose la sidebar et l'écran courant ; ne contient aucune logique métier —
/// tout passe par `SettingsViewModel` et les view models de section.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {

    static let shared = SettingsWindowController()

    private let settingsViewModel = SettingsViewModel()

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: SettingsMetrics.windowSize),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.center()

        self.init(window: window)

        window.delegate = self

        let root = SettingsRootViewController(viewModel: settingsViewModel) {
            SettingsStorage.shared.settings.general.enableAnimations
        }
        window.contentViewController = root
    }

    /// Seul chemin d'ouverture de la fenêtre — la menu bar, le menu contextuel des panneaux,
    /// `--show-settings` et ⌘, y aboutissent tous. L'icône du Dock apparaît donc exactement
    /// quand la fenêtre apparaît, et la fenêtre est unique : `isReleasedWhenClosed` est faux et
    /// l'instance est un singleton, donc une seconde ouverture ramène la même au premier plan.
    func show() {
        rerouteSettingsMenuItem()
        DockPresence.showIcon()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func show(_ category: SettingsCategory) {
        settingsViewModel.selectedCategory = category
        show()
    }

    // MARK: - NSWindowDelegate

    /// La fermeture de la fenêtre est le seul événement qui retire l'icône. Réduire la fenêtre
    /// dans le Dock ne la ferme pas : l'icône reste, et c'est elle qui permet de la ressortir.
    func windowWillClose(_ notification: Notification) {
        DockPresence.hideIcon()
    }

    // MARK: - ⌘,

    /// `Settings { EmptyView() }` fait porter à SwiftUI l'entrée « Settings… » ⌘, du menu de
    /// l'app. Invisible tant qu'on est `.accessory`, elle devient atteignable dès que l'icône du
    /// Dock fait aussi apparaître la menu bar — et ouvrirait alors une *seconde* fenêtre, vide.
    /// On la rebranche donc ici sur cette fenêtre-ci, avant toute bascule en `.regular`.
    ///
    /// L'opération est idempotente, d'où son appel à chaque `show()` plutôt qu'une seule fois au
    /// lancement : le menu principal est construit par SwiftUI, et on ne présume pas qu'il
    /// existe déjà à `applicationDidFinishLaunching`.
    private func rerouteSettingsMenuItem() {
        guard let appMenu = NSApp.mainMenu?.items.first?.submenu else { return }

        let swiftUISelectors: Set<String> = ["showSettingsWindow:", "showPreferencesWindow:"]

        for item in appMenu.items {
            let isSwiftUIItem = item.action.map { swiftUISelectors.contains(NSStringFromSelector($0)) } ?? false
            let isCommandComma = item.keyEquivalent == "," && item.keyEquivalentModifierMask == [.command]
            guard isSwiftUIItem || isCommandComma else { continue }

            item.target = self
            item.action = #selector(showFromMenuItem)
        }
    }

    @objc private func showFromMenuItem(_ sender: Any?) {
        Log.settings.debug("ouverture de la fenêtre de Préférences depuis ⌘,")
        show()
    }
}

/// Assemble la sidebar (fixe, à gauche) et l'écran courant (à droite), et anime le
/// changement d'onglet par un fondu croisé — jamais un simple `switch` instantané.
private final class SettingsRootViewController: NSViewController {

    private let viewModel: SettingsViewModel
    private let animationsEnabled: () -> Bool

    private let contentContainer = NSView()
    private var currentCategory: SettingsCategory?
    private var currentChild: NSViewController?
    private var cancellable: AnyCancellable?

    init(viewModel: SettingsViewModel, animationsEnabled: @escaping () -> Bool) {
        self.viewModel = viewModel
        self.animationsEnabled = animationsEnabled
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: SettingsMetrics.windowSize))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebar = SidebarView(viewModel: viewModel, animationsEnabled: animationsEnabled)
        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(sidebar)
        view.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: view.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: SettingsMetrics.sidebarWidth),

            contentContainer.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.topAnchor.constraint(equalTo: view.topAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        cancellable = viewModel.$selectedCategory.sink { [weak self] category in
            self?.show(category)
        }
    }

    private func show(_ category: SettingsCategory) {
        guard category != currentCategory else { return }

        let next = makeViewController(for: category)
        addChild(next)
        next.view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(next.view)
        NSLayoutConstraint.activate([
            next.view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            next.view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            next.view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            next.view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
        ])

        guard let current = currentChild else {
            currentChild = next
            currentCategory = category
            return
        }

        let finish = { [weak self] in
            current.view.removeFromSuperview()
            current.removeFromParent()
            self?.currentChild = next
            self?.currentCategory = category
        }

        if animationsEnabled() {
            next.view.alphaValue = 0
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = SettingsMetrics.transitionDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                current.view.animator().alphaValue = 0
                next.view.animator().alphaValue = 1
            }, completionHandler: finish)
        } else {
            finish()
        }
    }

    private func makeViewController(for category: SettingsCategory) -> NSViewController {
        switch category {
        case .general: return GeneralSettingsViewController(animationsEnabled: animationsEnabled)
        case .brightness: return BrightnessSettingsViewController(animationsEnabled: animationsEnabled)
        case .trackpad: return TrackpadSettingsViewController(animationsEnabled: animationsEnabled)
        case .about: return AboutSettingsViewController(animationsEnabled: animationsEnabled)
        }
    }
}

import AppKit
import Combine

/// La sidebar des Préférences : une entrée par `SettingsCategory`, très espacées, avec un
/// fond de sélection unique qui glisse d'une entrée à l'autre plutôt que de basculer un
/// fond par ligne — c'est ce qui donne la sensation de "transition fluide" de Klack.
final class SidebarView: NSView {

    private let viewModel: SettingsViewModel
    private let animationsEnabled: () -> Bool

    private let background = NSGlassEffectView()
    private let selectionView = SidebarSelectionView()
    private var itemViews: [SidebarItemView] = []
    private var cancellable: AnyCancellable?

    init(viewModel: SettingsViewModel, animationsEnabled: @escaping () -> Bool) {
        self.viewModel = viewModel
        self.animationsEnabled = animationsEnabled
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        // Force toute la sous-arborescence en layer-backed cohérent : sans ça, `selectionView`
        // (layer-backed pour ses coins arrondis) se compose toujours au-dessus de ses "siblings"
        // non layer-backed quel que soit l'ordre d'ajout, et cache l'icône/le texte de l'item
        // sélectionné derrière un pavé opaque.
        wantsLayer = true

        background.cornerRadius = 0
        translatesAutoresizingMaskIntoConstraints = false
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)
        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: topAnchor),
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        selectionView.wantsLayer = true
        selectionView.layer?.cornerRadius = SettingsMetrics.sidebarItemCornerRadius
        selectionView.layer?.cornerCurve = .continuous
        // Positionnement manuel par frame (pas de contraintes) : garder l'auto-resizing mask
        // désactivée pour ne pas la mêler à `translatesAutoresizingMaskIntoConstraints = false`
        // sans contrainte, ce qui laisserait le solveur Auto Layout réinitialiser sa frame à
        // chaque passage de layout.
        selectionView.autoresizingMask = []
        addSubview(selectionView)

        let stack = NSStackView(views: SettingsCategory.allCases.map(makeItemView))
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = SettingsMetrics.sidebarItemSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: SettingsMetrics.sidebarPadding + 20),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SettingsMetrics.sidebarPadding),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SettingsMetrics.sidebarPadding),
        ])

        for item in itemViews {
            item.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        cancellable = viewModel.$selectedCategory
            .sink { [weak self] category in
                self?.moveSelection(to: category, animated: true)
            }
    }

    private func makeItemView(for category: SettingsCategory) -> SidebarItemView {
        let item = SidebarItemView(category: category)
        item.onClick = { [weak self] category in
            self?.viewModel.selectedCategory = category
        }
        itemViews.append(item)
        return item
    }

    override func layout() {
        super.layout()
        moveSelection(to: viewModel.selectedCategory, animated: false)
    }

    private func moveSelection(to category: SettingsCategory, animated: Bool) {
        // Force la résolution des contraintes avant de lire les frames : sans ça, un appel
        // avant le premier passage de layout (ex. catégorie choisie avant l'affichage de la
        // fenêtre) lit des frames encore à zéro et l'intention est perdue silencieusement.
        layoutSubtreeIfNeeded()
        guard let target = itemViews.first(where: { $0.category == category }), let itemSuperview = target.superview else { return }
        // `target.frame` est exprimée dans le repère de son superview immédiat (la pile de la
        // sidebar), pas dans celui de `selectionView` (`self`) — conversion obligatoire.
        let frame = convert(target.frame, from: itemSuperview)

        let apply = { self.selectionView.frame = frame }

        if animated && animationsEnabled() {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = SettingsMetrics.transitionDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                selectionView.animator().frame = frame
            }
        } else {
            apply()
        }
    }
}

/// Fond de la sélection de la sidebar. `NSColor` → `CGColor` fige la couleur résolue pour
/// l'apparence courante au moment de l'appel : sans `updateLayer()`, ce fond reste bloqué sur
/// sa couleur d'origine (souvent blanc) après un changement clair/sombre. `wantsUpdateLayer`
/// fait appeler `updateLayer()` par AppKit à chaque changement d'apparence effective.
private final class SidebarSelectionView: NSView {
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = SettingsPalette.sidebarSelection.cgColor
    }
}

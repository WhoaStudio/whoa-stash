import AppKit

/// Vue document d'un `NSScrollView` en coordonnées "haut vers le bas" : sans ça, un contenu
/// plus court que la zone visible s'ancre en bas du scroll view (coordonnées AppKit par
/// défaut) au lieu de rester collé en haut, sous les cartes.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Base commune aux écrans de Préférences : une pile verticale de lignes de formulaire et de
/// filets, centrée dans un scroll view sans chrome visible, avec une apparition en fondu/glissé légère à
/// chaque affichage. Les sous-classes ne fournissent que leurs lignes.
class SettingsSectionViewController: NSViewController {

    private let animationsEnabled: () -> Bool
    private let stack = NSStackView()

    init(animationsEnabled: @escaping () -> Bool) {
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

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let documentView = FlippedView()
        documentView.translatesAutoresizingMaskIntoConstraints = false

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = SettingsMetrics.rowSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false

        documentView.addSubview(stack)
        scrollView.documentView = documentView
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            documentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            stack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: SettingsMetrics.contentTopInset),
            stack.centerXAnchor.constraint(equalTo: documentView.centerXAnchor),
            stack.widthAnchor.constraint(equalToConstant: SettingsMetrics.contentWidth),
            stack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -SettingsMetrics.contentBottomInset),
        ])

        for row in makeRows() {
            stack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        animateRowsIn()
    }

    /// Point d'extension : chaque écran fournit ses lignes de formulaire et ses filets.
    func makeRows() -> [NSView] { [] }

    private func animateRowsIn() {
        guard animationsEnabled() else { return }
        for (index, row) in stack.arrangedSubviews.enumerated() {
            row.wantsLayer = true
            guard let layer = row.layer else { continue }
            layer.opacity = 0
            layer.transform = CATransform3DMakeTranslation(0, 8, 0)

            let delay = Double(index) * 0.05
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                layer.springAnimate(keyPath: "opacity", to: 1, preset: .gentle)
                layer.springAnimate(keyPath: "transform", to: NSValue(caTransform3D: CATransform3DIdentity), preset: .gentle)
            }
        }
    }
}

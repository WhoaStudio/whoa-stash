import AppKit

/// Contenu du panneau latéral : l'en-tête « Claude Usage » et les deux fenêtres de quota, chacune
/// avec sa barre horizontale, son pourcentage et son instant de réinitialisation.
///
/// Mise en page en frames, comme le reste de l'overlay — `layout()` est la seule source de vérité
/// des positions, et les hauteurs sont des constantes nommées plutôt que des nombres répétés.
final class ClaudeUsagePanelView: NSView {

    private let markLayer = CAShapeLayer()
    private let titleLabel = NSTextField(labelWithString: "Claude Usage")
    private let sessionRow = ClaudeUsageRowView(title: "Current session")
    private let allModelsRow = ClaudeUsageRowView(title: "All models")

    let leadingInset: CGFloat = 22
    /// Réglée par la vue hôte selon sa silhouette : sur la carte accrochée au bord de l'écran, ce
    /// bord touche l'écran et les coins concaves y rognent la zone réellement peinte, donc la
    /// marge y est plus large que la gauche ; dans la bulle, les deux bords sont symétriques.
    var trailingInset: CGFloat = 26 {
        didSet {
            guard trailingInset != oldValue else { return }
            needsLayout = true
        }
    }
    private let verticalInset: CGFloat = 18
    private let headerHeight: CGFloat = 20
    private let headerSpacing: CGFloat = 16
    private let rowSpacing: CGFloat = 16

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        layer?.addSublayer(markLayer)

        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        addSubview(titleLabel)

        addSubview(sessionRow)
        addSubview(allModelsRow)

        applyPalette()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPalette()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        markLayer.contentsScale = window?.backingScaleFactor ?? 2
    }

    private func applyPalette() {
        let palette = OverlayPalette.resolved(for: effectiveAppearance)
        titleLabel.textColor = palette.buttonSymbolColor
        markLayer.fillColor = palette.buttonSymbolColor.cgColor
        sessionRow.applyPalette()
        allModelsRow.applyPalette()
    }

    // MARK: - État

    func apply(_ state: ClaudeUsageState, animated: Bool) {
        switch state {
        case .loaded(let snapshot):
            sessionRow.apply(window: snapshot.session, animated: animated)
            allModelsRow.apply(window: snapshot.allModels, animated: animated)
        case .loading:
            sessionRow.applyPlaceholder(detail: "Loading…")
            allModelsRow.applyPlaceholder(detail: "Loading…")
        case .unavailable(let reason):
            sessionRow.applyPlaceholder(detail: reason)
            allModelsRow.applyPlaceholder(detail: "")
        }
    }

    // MARK: - Mise en page

    override func layout() {
        super.layout()

        let contentWidth = bounds.width - leadingInset - trailingInset
        let headerTop = bounds.maxY - verticalInset - headerHeight

        let markSize = headerHeight * 0.82
        markLayer.frame = bounds
        markLayer.path = UsageMarkPath.claude.path(
            in: CGRect(
                x: leadingInset,
                y: headerTop + (headerHeight - markSize) / 2,
                width: markSize,
                height: markSize
            )
        )

        let titleSize = titleLabel.intrinsicContentSize
        titleLabel.frame = NSRect(
            x: leadingInset + markSize + 8,
            y: headerTop + (headerHeight - titleSize.height) / 2,
            width: titleSize.width,
            height: titleSize.height
        )

        let rowHeight = ClaudeUsageRowView.height
        let sessionTop = headerTop - headerSpacing - rowHeight
        sessionRow.frame = NSRect(x: leadingInset, y: sessionTop, width: contentWidth, height: rowHeight)
        allModelsRow.frame = NSRect(
            x: leadingInset,
            y: sessionTop - rowSpacing - rowHeight,
            width: contentWidth,
            height: rowHeight
        )
    }
}

/// Une ligne du panneau : intitulé à gauche, réinitialisation à droite, barre pleine largeur
/// dessous, puis « 73 % Used ».
private final class ClaudeUsageRowView: NSView {

    static let titleHeight: CGFloat = 16
    static let barHeight: CGFloat = 6
    static let usedHeight: CGFloat = 15
    static let innerSpacing: CGFloat = 7
    static var height: CGFloat { titleHeight + innerSpacing + barHeight + innerSpacing + usedHeight }

    private let titleLabel: NSTextField
    private let resetLabel = NSTextField(labelWithString: "")
    private let usedLabel = NSTextField(labelWithString: "")
    private let trackLayer = CALayer()
    private let fillLayer = CALayer()
    private var utilization: Double = 0

    init(title: String) {
        titleLabel = NSTextField(labelWithString: title)
        super.init(frame: .zero)
        wantsLayer = true
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        resetLabel.font = .systemFont(ofSize: 11, weight: .regular)
        resetLabel.alignment = .right
        usedLabel.font = .systemFont(ofSize: 11.5, weight: .medium)

        addSubview(titleLabel)
        addSubview(resetLabel)
        addSubview(usedLabel)

        layer?.addSublayer(trackLayer)

        // Ancré à gauche : c'est la largeur qui est animée, et la barre doit grandir vers la
        // droite sans que son origine ne bouge.
        fillLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
        layer?.addSublayer(fillLayer)

        applyPalette()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPalette()
    }

    func applyPalette() {
        let palette = OverlayPalette.resolved(for: effectiveAppearance)
        titleLabel.textColor = palette.buttonSymbolColor
        usedLabel.textColor = palette.buttonSymbolColor
        resetLabel.textColor = .secondaryLabelColor
        trackLayer.backgroundColor = ClaudeUsagePalette.track(for: effectiveAppearance)
    }

    func apply(window: ClaudeUsageWindow, animated: Bool) {
        resetLabel.stringValue = ClaudeUsageFormatting.resetText(for: window.resetsAt)
        usedLabel.stringValue = "\(window.percentage)% Used"
        utilization = window.utilization
        needsLayout = true
        updateFill(animated: animated)
    }

    func applyPlaceholder(detail: String) {
        resetLabel.stringValue = detail
        usedLabel.stringValue = "—"
        utilization = 0
        needsLayout = true
        updateFill(animated: false)
    }

    /// Seul endroit qui fixe la largeur du remplissage. `apply` et `layout` y passent tous les
    /// deux : a la premiere passe la vue n'a pas encore de largeur et seule la mise en page peut
    /// donner la bonne valeur ; ensuite c'est `apply` qui l'anime.
    private func updateFill(animated: Bool) {
        let width = bounds.width * CGFloat(utilization)
        let color = ClaudeUsagePalette.color(for: utilization)

        guard animated, bounds.width > 0 else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            fillLayer.bounds.size.width = width
            fillLayer.backgroundColor = color
            CATransaction.commit()
            return
        }

        fillLayer.springAnimate(keyPath: "bounds.size.width", to: width, preset: .gentle)
        fillLayer.backgroundColor = color
    }

    override func layout() {
        super.layout()

        let titleTop = bounds.maxY - Self.titleHeight
        let titleSize = titleLabel.intrinsicContentSize
        titleLabel.frame = NSRect(x: 0, y: titleTop, width: titleSize.width, height: Self.titleHeight)

        let resetSize = resetLabel.intrinsicContentSize
        // Le libellé de droite ne mord jamais sur celui de gauche : il est tronqué par la
        // largeur disponible plutôt que de se superposer quand la locale est verbeuse.
        let resetX = max(titleSize.width + 8, bounds.width - resetSize.width)
        resetLabel.frame = NSRect(x: resetX, y: titleTop, width: bounds.width - resetX, height: Self.titleHeight)

        let barY = titleTop - Self.innerSpacing - Self.barHeight
        trackLayer.frame = NSRect(x: 0, y: barY, width: bounds.width, height: Self.barHeight)
        trackLayer.cornerRadius = Self.barHeight / 2

        fillLayer.bounds.size.height = Self.barHeight
        fillLayer.position = CGPoint(x: 0, y: barY + Self.barHeight / 2)
        fillLayer.cornerRadius = Self.barHeight / 2
        updateFill(animated: false)

        let usedSize = usedLabel.intrinsicContentSize
        usedLabel.frame = NSRect(x: 0, y: bounds.minY, width: usedSize.width, height: Self.usedHeight)
    }
}

import AppKit

/// Le widget calendrier de l'onglet Global : l'en-tête de date et l'agenda à gauche, la grille du
/// mois à droite, séparés par le même filet que les deux colonnes de l'onglet AI.
///
/// N'importe pas EventKit et ne connaît pas sa source : il reçoit un `CalendarAgendaState` et
/// l'affiche. C'est tout l'objet de `CalendarAgendaProviding`.
///
/// L'en-tête et la grille ne dépendent que de la date : ils continuent de s'afficher quand
/// l'accès aux calendriers est refusé, et seul l'agenda porte alors un écriteau.
final class CalendarWidgetView: NSView {

    /// Le jour et sa date — « Mon 27 ». La ligne d'accroche du widget, donc la seule en gros.
    private let dayLabel = NSTextField(labelWithString: "")

    /// Le numéro de semaine et le mois — « W44 · October ». En retrait sous le jour.
    private let contextLabel = NSTextField(labelWithString: "")

    private let agendaList = AgendaListView()
    private let monthGrid = MonthGridView()
    private let dividerLayer = CALayer()

    /// Jour couvert par l'en-tête. Recalculé à chaque reconstruction, le panneau pouvant rester
    /// en mémoire d'un jour à l'autre.
    private var referenceDate = Date()

    private let calendar = Calendar.current

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE d")
        return formatter
    }()

    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter
    }()

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
        for field in [dayLabel, contextLabel] {
            field.isBezeled = false
            field.drawsBackground = false
            field.isEditable = false
            field.isSelectable = false
            field.alignment = .left
            field.lineBreakMode = .byTruncatingTail
            addSubview(field)
        }

        dayLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        contextLabel.font = .systemFont(ofSize: 11, weight: .medium)

        layer?.addSublayer(dividerLayer)
        addSubview(agendaList)
        addSubview(monthGrid)

        refresh()
        applyPalette()
    }

    // MARK: - État

    func apply(_ state: CalendarAgendaState) {
        agendaList.apply(state)
    }

    /// Remet l'en-tête et la grille à la bonne date. Appelé à chaque dépliage du panneau, comme
    /// `WeekStripView.refresh()` : sans ça, le widget afficherait la date du jour où il a été
    /// construit.
    func refresh(now date: Date = Date()) {
        referenceDate = date
        dayLabel.stringValue = dayFormatter.string(from: date)

        // « W44 » : l'interface de l'app est en anglais, seules les dates suivent la langue du
        // système — comme les initiales de `WeekStripView`.
        let week = calendar.component(.weekOfYear, from: date)
        contextLabel.stringValue = "W\(week) · \(monthFormatter.string(from: date))"

        monthGrid.refresh(now: date)
        needsLayout = true
    }

    // MARK: - Palette

    private func applyPalette() {
        let palette = OverlayPalette.resolved(for: effectiveAppearance)
        dayLabel.textColor = palette.tabActiveContent
        contextLabel.textColor = palette.tabInactiveContent
        dividerLayer.backgroundColor = palette.strokeColor
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPalette()
    }

    // MARK: - Mise en page

    override func layout() {
        super.layout()

        // La grille est calée à droite, à sa largeur propre ; l'agenda prend tout ce qui reste à
        // gauche. Le filet se pose entre les deux, à égale distance — le même écart que celui des
        // colonnes de l'onglet AI.
        let gridWidth = min(NotchPanelGeometry.monthGridWidth, bounds.width / 2)
        let gap = NotchPanelGeometry.columnGap
        let dividerX = (bounds.maxX - gridWidth - gap - NotchPanelGeometry.dividerWidth).rounded()

        dividerLayer.frame = NSRect(
            x: dividerX,
            y: bounds.minY,
            width: NotchPanelGeometry.dividerWidth,
            height: bounds.height
        )

        monthGrid.frame = NSRect(
            x: (bounds.maxX - gridWidth).rounded(),
            y: bounds.minY,
            width: gridWidth,
            height: bounds.height
        )

        let leftWidth = max(0, dividerX - gap - bounds.minX)

        let dayHeight = dayLabel.intrinsicContentSize.height
        dayLabel.frame = NSRect(
            x: bounds.minX,
            y: bounds.maxY - dayHeight,
            width: leftWidth,
            height: dayHeight
        )

        let contextHeight = contextLabel.intrinsicContentSize.height
        contextLabel.frame = NSRect(
            x: bounds.minX,
            y: dayLabel.frame.minY - contextHeight,
            width: leftWidth,
            height: contextHeight
        )

        // L'agenda prend tout ce qui reste sous l'en-tête et décide lui-même combien de lignes y
        // tiennent.
        let agendaTop = contextLabel.frame.minY - NotchPanelGeometry.calendarHeaderGap
        agendaList.frame = NSRect(
            x: bounds.minX,
            y: bounds.minY,
            width: leftWidth,
            height: max(0, agendaTop - bounds.minY)
        )
    }
}

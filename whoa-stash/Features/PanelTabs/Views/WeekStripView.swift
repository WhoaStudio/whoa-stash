import AppKit

/// Bande de la semaine en cours : sept cases, l'initiale du jour au-dessus de son numéro.
/// Le jour courant porte une pastille pleine sous son numéro.
///
/// La semaine commence le jour que dit le calendrier de l'utilisateur (`firstWeekday`) — lundi
/// en France, dimanche aux États-Unis — et non un lundi codé en dur.
final class WeekStripView: NSView {

    private var cells: [WeekDayCellView] = []

    /// Jour affiché comme « aujourd'hui ». Recalculé à chaque reconstruction : le panneau peut
    /// rester en mémoire plusieurs jours sans que l'app redémarre.
    private var referenceDate = Date()

    private let calendar = Calendar.current

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        rebuild()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Reconstruit la semaine autour de `date`. À appeler avant chaque apparition du panneau :
    /// sans ça, la pastille resterait sur le jour où les cases ont été créées.
    func refresh(now date: Date = Date()) {
        guard !calendar.isDate(date, inSameDayAs: referenceDate) || cells.isEmpty else { return }
        referenceDate = date
        rebuild()
    }

    private func rebuild() {
        cells.forEach { $0.removeFromSuperview() }
        cells = days(of: referenceDate).map { day in
            WeekDayCellView(
                initial: initial(for: day),
                dayNumber: calendar.component(.day, from: day),
                isToday: calendar.isDateInToday(day),
                isWeekend: calendar.isDateInWeekend(day)
            )
        }
        cells.forEach(addSubview)
        needsLayout = true
    }

    /// Les sept jours de la semaine qui contient `date`, dans l'ordre d'affichage.
    private func days(of date: Date) -> [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return [date] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }

    /// Première lettre du jour, prise dans les noms très courts du calendrier plutôt que tronquée
    /// à la main : toutes les langues n'abrègent pas en coupant au premier caractère.
    private func initial(for date: Date) -> String {
        let index = calendar.component(.weekday, from: date) - 1
        let symbols = calendar.veryShortWeekdaySymbols
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index].uppercased()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        cells.forEach { $0.applyPalette() }
    }

    override func layout() {
        super.layout()
        guard !cells.isEmpty else { return }

        // Les cases se partagent toute la largeur à parts égales. Les bornes sont calculées
        // depuis le bord puis arrondies au point, et non cumulées case après case : un arrondi
        // par case laisserait dériver la dernière.
        let count = CGFloat(cells.count)
        for (position, cell) in cells.enumerated() {
            let minX = (bounds.width * CGFloat(position) / count).rounded()
            let maxX = (bounds.width * CGFloat(position + 1) / count).rounded()
            cell.frame = NSRect(x: minX, y: bounds.minY, width: max(1, maxX - minX), height: bounds.height)
        }
    }
}

// MARK: - Une case

/// Une case de la bande : l'initiale du jour, et son numéro dans une pastille qui n'est peinte
/// que pour aujourd'hui.
private final class WeekDayCellView: NSView {

    private let initialLabel = NSTextField(labelWithString: "")
    private let numberLabel = NSTextField(labelWithString: "")
    private let pillLayer = CALayer()
    private let isToday: Bool
    private let isWeekend: Bool

    /// Côté de la pastille du jour courant.
    private let pillSize: CGFloat = 24

    init(initial: String, dayNumber: Int, isToday: Bool, isWeekend: Bool) {
        self.isToday = isToday
        self.isWeekend = isWeekend
        super.init(frame: .zero)
        wantsLayer = true

        pillLayer.cornerRadius = pillSize / 2
        pillLayer.cornerCurve = .continuous
        layer?.addSublayer(pillLayer)

        for (field, text) in [(initialLabel, initial), (numberLabel, "\(dayNumber)")] {
            field.stringValue = text
            field.isBezeled = false
            field.drawsBackground = false
            field.isEditable = false
            field.isSelectable = false
            field.alignment = .center
            addSubview(field)
        }

        initialLabel.font = .systemFont(ofSize: 10, weight: .medium)
        numberLabel.font = .systemFont(ofSize: 13, weight: isToday ? .bold : .regular)

        applyPalette()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyPalette() {
        let palette = OverlayPalette.resolved(for: effectiveAppearance)
        // La bande se lit comme la grille du mois : la semaine ouvrée franche, le week-end en
        // retrait, et le jour courant blanc sur sa pastille rouge.
        let dayColor = isWeekend ? palette.calendarWeekendContent : palette.calendarDayContent
        initialLabel.textColor = dayColor
        numberLabel.textColor = isToday ? palette.tabActiveContent : dayColor
        pillLayer.backgroundColor = isToday ? palette.calendarTodayFill : nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        applyPalette()
    }

    override func layout() {
        super.layout()

        let initialHeight = initialLabel.intrinsicContentSize.height
        initialLabel.frame = NSRect(
            x: bounds.minX,
            y: bounds.maxY - initialHeight,
            width: bounds.width,
            height: initialHeight
        )

        let pill = NSRect(
            x: bounds.midX - pillSize / 2,
            y: initialLabel.frame.minY - 4 - pillSize,
            width: pillSize,
            height: pillSize
        )
        pillLayer.frame = pill

        let numberHeight = numberLabel.intrinsicContentSize.height
        numberLabel.frame = NSRect(
            x: bounds.minX,
            y: pill.midY - numberHeight / 2,
            width: bounds.width,
            height: numberHeight
        )
    }
}

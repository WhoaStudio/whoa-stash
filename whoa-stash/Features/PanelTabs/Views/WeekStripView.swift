import AppKit

/// Bande horizontale de trois semaines, centrée sur le jour courant au premier affichage.
/// Le calendrier de l'utilisateur décide du premier jour de la semaine.
final class WeekStripView: NSView {

    private static let dayWidth: CGFloat = 44
    private static let dayGap: CGFloat = 8
    private static let dayCount = 21
    private static let snapDelay: TimeInterval = 0.12

    private let scrollView = WeekStripScrollView()
    private let documentView = NSView()
    private var cells: [WeekDayCellView] = []
    private var days: [Date] = []
    private var centeredIndex: Int?
    private var snapWorkItem: DispatchWorkItem?

    /// Jour affiché comme « aujourd'hui ». Recalculé à chaque reconstruction : le panneau peut
    /// rester en mémoire plusieurs jours sans que l'app redémarre.
    private var referenceDate = Date()

    private let calendar = Calendar.current
    private let feedback: OverlayFeedback

    init(frame frameRect: NSRect = .zero, feedback: OverlayFeedback = SystemOverlayFeedback()) {
        self.feedback = feedback
        super.init(frame: frameRect)
        wantsLayer = true
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setUp() {
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        scrollView.documentView = documentView
        scrollView.onScroll = { [weak self] event in
            self?.handleScroll(event)
        }
        addSubview(scrollView)

        rebuild()
    }

    /// Reconstruit les trois semaines autour de `date`. À appeler avant chaque apparition du
    /// panneau : sans ça, la sélection resterait sur le jour où les cases ont été créées.
    func refresh(now date: Date = Date()) {
        guard !calendar.isDate(date, inSameDayAs: referenceDate) || days.isEmpty else { return }
        referenceDate = date
        rebuild()
    }

    private func rebuild() {
        snapWorkItem?.cancel()
        snapWorkItem = nil

        cells.forEach { $0.removeFromSuperview() }
        days = daysAround(referenceDate)
        cells = days.map { day in
            WeekDayCellView(
                initial: initial(for: day),
                dayNumber: calendar.component(.day, from: day),
                isToday: calendar.isDateInToday(day),
                isWeekend: calendar.isDateInWeekend(day)
            )
        }
        cells.forEach(documentView.addSubview)
        centeredIndex = nil
        needsLayout = true
    }

    /// Les 21 jours allant du début de la semaine précédente à la fin de la semaine suivante.
    private func daysAround(_ date: Date) -> [Date] {
        guard
            let currentWeek = calendar.dateInterval(of: .weekOfYear, for: date),
            let firstDay = calendar.date(byAdding: .day, value: -7, to: currentWeek.start)
        else {
            return [date]
        }

        return (0..<Self.dayCount).compactMap {
            calendar.date(byAdding: .day, value: $0, to: firstDay)
        }
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

        scrollView.frame = bounds

        let sideInset = max(0, (bounds.width - Self.dayWidth) / 2)
        let documentWidth = sideInset * 2
            + CGFloat(max(0, cells.count - 1)) * (Self.dayWidth + Self.dayGap)
            + Self.dayWidth
        documentView.frame = NSRect(x: 0, y: 0, width: documentWidth, height: bounds.height)

        for (position, cell) in cells.enumerated() {
            let x = sideInset + CGFloat(position) * (Self.dayWidth + Self.dayGap)
            cell.frame = NSRect(x: x, y: bounds.minY, width: Self.dayWidth, height: bounds.height)
        }

        if centeredIndex == nil, !days.isEmpty {
            let today = days.firstIndex(where: { calendar.isDateInToday($0) }) ?? days.count / 2
            centeredIndex = today
            scrollTo(index: today, animated: false)
        }
    }

    private func handleScroll(_ event: NSEvent) {
        let index = nearestCenteredIndex()
        if index != centeredIndex {
            if let centeredIndex {
                let step = index > centeredIndex ? 1 : -1
                for _ in stride(from: centeredIndex + step, through: index, by: step) {
                    feedback.tickCrossed()
                }
            }
            centeredIndex = index
        }

        snapWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.scrollTo(index: index, animated: true)
        }
        snapWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.snapDelay, execute: workItem)

        if event.phase == .ended || event.momentumPhase == .ended {
            scrollTo(index: index, animated: true)
        }
    }

    private func nearestCenteredIndex() -> Int {
        guard !days.isEmpty else { return 0 }

        let center = scrollView.contentView.bounds.midX
        let sideInset = max(0, (bounds.width - Self.dayWidth) / 2)
        let position = (center - sideInset - Self.dayWidth / 2) / (Self.dayWidth + Self.dayGap)
        return min(max(Int(position.rounded()), 0), days.count - 1)
    }

    private func scrollTo(index: Int, animated: Bool) {
        guard cells.indices.contains(index) else { return }

        let sideInset = max(0, (bounds.width - Self.dayWidth) / 2)
        let targetX = sideInset
            + CGFloat(index) * (Self.dayWidth + Self.dayGap)
            + Self.dayWidth / 2
            - bounds.width / 2
        let maxX = max(0, documentView.bounds.width - bounds.width)
        let origin = NSPoint(x: min(max(targetX, 0), maxX), y: 0)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                scrollView.contentView.animator().setBoundsOrigin(origin)
            }
        } else {
            scrollView.contentView.setBoundsOrigin(origin)
        }
    }
}

private final class WeekStripScrollView: NSScrollView {

    var onScroll: ((NSEvent) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        onScroll?(event)
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

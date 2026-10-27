import Foundation

/// Disposition d'un mois en cases, indépendante de tout dessin : `MonthGridView` ne fait que la
/// tracer. Séparée de la vue pour être vérifiable — le découpage d'un mois en semaines dépend du
/// premier jour de la semaine chez l'utilisateur, et c'est exactement le genre de calcul qu'on ne
/// veut pas vérifier à l'œil sur une capture d'écran.
nonisolated struct MonthGridLayout: Equatable {

    /// Nombre de lignes de semaines toujours produites. Six, et non le nombre que le mois
    /// demande : un mois de cinq lignes et un de six ne doivent pas faire sauter la hauteur des
    /// cases d'un mois à l'autre.
    static let weekRowCount = 6

    static let columnCount = 7

    /// Les cases, de la première colonne de la première semaine à la dernière : `nil` pour ce qui
    /// tombe hors du mois.
    let days: [Int?]

    /// Case du jour courant, ou `nil` quand le mois affiché n'est pas celui d'aujourd'hui.
    let todayIndex: Int?

    /// Initiales des sept colonnes, dans l'ordre d'affichage.
    let weekdayInitials: [String]

    init(date: Date, calendar: Calendar = .current, today: Date = Date()) {
        self.weekdayInitials = Self.initials(calendar: calendar)

        guard
            let month = calendar.dateInterval(of: .month, for: date),
            let dayRange = calendar.range(of: .day, in: .month, for: date)
        else {
            self.days = Array(repeating: nil, count: Self.columnCount * Self.weekRowCount)
            self.todayIndex = nil
            return
        }

        // Cases vides avant le premier du mois : l'écart entre le jour de semaine du 1er et le
        // premier jour de la semaine chez l'utilisateur, ramené dans 0…6.
        let firstWeekday = calendar.component(.weekday, from: month.start)
        let leading = (firstWeekday - calendar.firstWeekday + Self.columnCount) % Self.columnCount

        var cells: [Int?] = Array(repeating: nil, count: leading)
        cells.append(contentsOf: dayRange.map { Optional($0) })
        let total = Self.columnCount * Self.weekRowCount
        cells.append(contentsOf: Array(repeating: nil, count: max(0, total - cells.count)))
        self.days = Array(cells.prefix(total))

        // La pastille ne se pose que si le mois affiché est celui d'`today` — la grille suit la
        // date qu'on lui donne, qui pourra un jour ne pas être le jour courant.
        if calendar.isDate(date, equalTo: today, toGranularity: .month) {
            self.todayIndex = leading + calendar.component(.day, from: today) - 1
        } else {
            self.todayIndex = nil
        }
    }

    /// Prises dans les noms très courts du calendrier plutôt que tronquées à la main : toutes les
    /// langues n'abrègent pas en coupant au premier caractère.
    private static func initials(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        guard symbols.count == columnCount else { return Array(repeating: "", count: columnCount) }
        return (0..<columnCount).map { symbols[(calendar.firstWeekday - 1 + $0) % columnCount].uppercased() }
    }
}

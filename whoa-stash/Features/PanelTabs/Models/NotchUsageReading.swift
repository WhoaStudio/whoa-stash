import Foundation

/// Les fournisseurs de l'onglet AI, dans l'ordre où l'en-tête les présente.
enum NotchUsageProvider: Int, CaseIterable {
    case claude
    case codex
    case copilot

    var name: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .copilot: "GitHub Copilot"
        }
    }

    var mark: UsageMarkPath {
        switch self {
        case .claude: .claude
        case .codex: .codex
        case .copilot: .copilot
        }
    }
}

/// Ce que l'onglet AI montre d'un fournisseur : une seule fenêtre de quota, celle que porte son
/// onglet d'en-tête, plus ce que la carte en dit. Calculé une fois ici pour que l'onglet et la
/// carte ne puissent pas afficher deux pourcentages différents du même instantané.
struct NotchUsageReading: Equatable {

    enum Status: Equatable {
        case loading
        case loaded
        case unavailable(reason: String)
    }

    /// Étiquette de la fenêtre : « 5H », « 7D », « MO ».
    let windowLabel: String
    let status: Status
    /// Fraction **restante**, `0…1` — c'est elle que montrent l'onglet, le titre de la carte et
    /// la barre.
    let remaining: Double?
    let resetsAt: Date?
    /// Ligne sous la barre, quand la source en fournit une vraie.
    let secondaryLine: String?

    var remainingPercentage: Int? { remaining.map { Int(($0 * 100).rounded()) } }

    static func loading(windowLabel: String) -> NotchUsageReading {
        NotchUsageReading(windowLabel: windowLabel, status: .loading, remaining: nil, resetsAt: nil, secondaryLine: nil)
    }

    static func unavailable(windowLabel: String, reason: String) -> NotchUsageReading {
        NotchUsageReading(
            windowLabel: windowLabel, status: .unavailable(reason: reason),
            remaining: nil, resetsAt: nil, secondaryLine: nil)
    }

    private static func loaded(
        windowLabel: String, window: ClaudeUsageWindow, secondaryLine: String? = nil
    ) -> NotchUsageReading {
        NotchUsageReading(
            windowLabel: windowLabel, status: .loaded,
            remaining: 1 - window.utilization, resetsAt: window.resetsAt, secondaryLine: secondaryLine)
    }

    /// Claude : la session de 5 h porte l'onglet ; le quota hebdomadaire passe sous la barre.
    static func claude(_ state: ClaudeUsageState) -> NotchUsageReading {
        switch state {
        case .loading:
            return .loading(windowLabel: "5H")
        case let .unavailable(reason):
            return .unavailable(windowLabel: "5H", reason: reason)
        case let .loaded(snapshot):
            let weekly = Int(((1 - snapshot.allModels.utilization) * 100).rounded())
            return .loaded(
                windowLabel: "5H", window: snapshot.session, secondaryLine: "7D \(weekly)% remaining")
        }
    }

    /// Copilot : le quota mensuel d'interactions premium. La source ne donne rien d'autre.
    static func copilot(_ state: CopilotUsageState) -> NotchUsageReading {
        switch state {
        case .loading:
            return .loading(windowLabel: "MO")
        case let .unavailable(reason):
            return .unavailable(windowLabel: "MO", reason: reason)
        case let .loaded(snapshot):
            return .loaded(windowLabel: "MO", window: snapshot.premiumInteractions)
        }
    }

    /// TODO: Codex n'a aucune source de données (`ringSlots` le marque non branché). Tant qu'il
    /// n'en a pas, son onglet reste vide plutôt que d'afficher un chiffre inventé.
    static let codex = NotchUsageReading.unavailable(windowLabel: "7D", reason: "Not connected")
}

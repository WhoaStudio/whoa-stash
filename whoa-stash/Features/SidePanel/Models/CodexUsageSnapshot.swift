import Foundation

/// Les deux fenêtres de quota de Codex : la session glissante de 5 h et le quota hebdomadaire.
/// Chacune peut manquer — certains forfaits n'exposent que l'hebdomadaire.
struct CodexUsageSnapshot: Equatable, Sendable {
    let fiveHour: ClaudeUsageWindow?
    let weekly: ClaudeUsageWindow?
}

enum CodexUsageState: Equatable {
    case loading
    case loaded(CodexUsageSnapshot)
    case unavailable(reason: String)

    var snapshot: CodexUsageSnapshot? {
        if case let .loaded(snapshot) = self { return snapshot }
        return nil
    }
}

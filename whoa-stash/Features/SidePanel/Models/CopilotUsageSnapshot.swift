import Foundation

struct CopilotUsageSnapshot: Equatable, Sendable {
    let premiumInteractions: ClaudeUsageWindow
    let monthlyReset: Date
}

enum CopilotUsageState: Equatable {
    case loading
    case loaded(CopilotUsageSnapshot)
    case unavailable(reason: String)

    var snapshot: CopilotUsageSnapshot? {
        if case let .loaded(snapshot) = self { return snapshot }
        return nil
    }

    var ringState: ClaudeUsageState {
        switch self {
        case .loading:
            return .loading
        case let .loaded(snapshot):
            return .loaded(
                ClaudeUsageSnapshot(
                    session: snapshot.premiumInteractions,
                    allModels: ClaudeUsageWindow(utilization: 0, resetsAt: snapshot.monthlyReset)
                )
            )
        case let .unavailable(reason):
            return .unavailable(reason: reason)
        }
    }
}

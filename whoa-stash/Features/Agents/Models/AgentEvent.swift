import Foundation

/// Ce qu'un agent IA signale à l'encoche : une session terminée, une question ou une permission
/// en attente, ou une réponse de Claude Desktop prête.
nonisolated struct AgentEvent: Equatable, Sendable {

    nonisolated enum Kind: String, Sendable {
        case finished
        case needsInput
        case desktopReply

        var statusText: String {
            switch self {
            case .finished: "Finished"
            case .needsInput: "Needs input"
            case .desktopReply: "Reply ready"
            }
        }

        var symbolName: String {
            switch self {
            case .finished, .desktopReply: "checkmark.circle.fill"
            case .needsInput: "questionmark.bubble.fill"
            }
        }
    }

    var kind: Kind
    /// Nom du dossier du projet, ou « Claude » pour Claude Desktop.
    var project: String

    /// Décode une ligne du script de hook : `{"kind":"stop"|"notify","payload":{…entrée du hook…}}`.
    /// Renvoie `nil` pour tout ce qui n'est pas reconnu — un message étranger sur le socket est ignoré.
    static func decode(_ data: Data) -> AgentEvent? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rawKind = root["kind"] as? String
        else { return nil }

        let kind: Kind
        switch rawKind {
        case "stop": kind = .finished
        case "notify": kind = .needsInput
        default: return nil
        }

        let payload = root["payload"] as? [String: Any]
        // Une notification d'inactivité (« Claude is waiting for your input ») est une fin de tour,
        // pas une demande de permission : on l'affiche comme telle.
        let cwd = (payload?["cwd"] as? String) ?? ""
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return AgentEvent(kind: kind, project: name.isEmpty || name == "/" ? "Claude Code" : name)
    }

    /// `--agent-event=stop|notify[,projet]` substitue un événement fixe aux hooks, pour vérifier la
    /// notification sans lancer Claude Code.
    static func fromLaunchArguments(_ arguments: [String] = CommandLine.arguments) -> AgentEvent? {
        guard let argument = arguments.first(where: { $0.hasPrefix("--agent-event=") }) else { return nil }
        let parts = argument.dropFirst("--agent-event=".count).split(separator: ",", maxSplits: 1)
        guard let kind = parts.first else { return nil }
        let project = parts.dropFirst().first.map(String.init) ?? "whoa-stash"
        switch kind {
        case "stop": return AgentEvent(kind: .finished, project: project)
        case "notify": return AgentEvent(kind: .needsInput, project: project)
        default: return nil
        }
    }
}

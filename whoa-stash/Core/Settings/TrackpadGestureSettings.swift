import Foundation

/// Côté du trackpad où se fait un tap de bord.
nonisolated enum TrackpadSide: String, Codable, CaseIterable, Sendable {
    case left
    case right
}

/// Ce que déclenche un tap de bord. Les cas qui envoient une frappe synthétique demandent la
/// permission Accessibilité (`requiresAccessibility`).
enum EdgeTapAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case displayOff
    case lockScreen
    case startScreenSaver
    case missionControl
    case playPause
    case nextTrack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .displayOff: return "Turn display off"
        case .lockScreen: return "Lock screen"
        case .startScreenSaver: return "Start screen saver"
        case .missionControl: return "Mission Control"
        case .playPause: return "Play / Pause"
        case .nextTrack: return "Next track"
        }
    }

    /// Vrai quand l'action passe par une frappe envoyée au système (⌃⌘Q pour verrouiller).
    var requiresAccessibility: Bool { self == .lockScreen }
}

/// Réglages des taps de bord du trackpad : une action par combinaison côté × nombre de taps.
struct TrackpadGestureSettings: Codable, Equatable, Sendable {
    var enabled: Bool = true
    var leftSingle: EdgeTapAction = .none
    var leftDouble: EdgeTapAction = .none
    var rightSingle: EdgeTapAction = .displayOff
    var rightDouble: EdgeTapAction = .none

    func action(side: TrackpadSide, taps: Int) -> EdgeTapAction {
        switch (side, taps) {
        case (.left, 1): return leftSingle
        case (.left, _): return leftDouble
        case (.right, 1): return rightSingle
        case (.right, _): return rightDouble
        }
    }

    /// Les côtés où un double tap est associé à une action : sur les autres, le tap simple part
    /// tout de suite au lieu d'attendre un éventuel second tap.
    var sidesWithDoubleTap: Set<TrackpadSide> {
        var sides = Set<TrackpadSide>()
        if leftDouble != .none { sides.insert(.left) }
        if rightDouble != .none { sides.insert(.right) }
        return sides
    }

    var requiresAccessibility: Bool {
        enabled && [leftSingle, leftDouble, rightSingle, rightDouble].contains { $0.requiresAccessibility }
    }
}

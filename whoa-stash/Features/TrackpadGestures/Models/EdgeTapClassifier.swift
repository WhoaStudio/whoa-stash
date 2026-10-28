import Foundation

/// Un doigt posé sur le trackpad, en coordonnées normalisées (0...1, origine en bas à gauche).
nonisolated struct TrackpadTouch: Equatable, Sendable {
    var id: Int32
    var x: Float
    var y: Float
    /// Taille du contact rapportée par le matériel ; sert à écarter les paumes.
    var size: Float
}

nonisolated struct EdgeTap: Equatable, Sendable {
    var side: TrackpadSide
    /// 1 pour un tap simple, 2 pour un double tap.
    var count: Int
}

/// Transforme un flux de frames tactiles en taps de bord. Pur : le temps est fourni par
/// l'appelant (`at:`), sans minuteur interne, donc entièrement testable.
///
/// Un tap est un contact unique, court, quasi immobile, posé dans une zone de bord. Un second
/// tap du même côté dans `doubleTapGap` le transforme en double tap ; le tap simple en attente
/// est alors annulé. Sans action de double tap sur ce côté, le tap simple part immédiatement.
nonisolated struct EdgeTapClassifier {

    var edgeZone: Float = 0.2
    var maxDuration: TimeInterval = 0.25
    var maxMovement: Float = 0.03
    var maxSize: Float = 2.0
    var doubleTapGap: TimeInterval = 0.3
    /// Côtés dont le double tap a une action : le tap simple y est retenu en attente.
    var doubleTapSides: Set<TrackpadSide> = []

    private struct Candidate {
        var id: Int32
        var startTime: TimeInterval
        var startX: Float
        var startY: Float
        var side: TrackpadSide
    }

    private var candidate: Candidate?
    /// Vrai tant que le contact en cours ne peut plus être un tap (déplacé, trop long, paume,
    /// plusieurs doigts, hors zone) ; levé quand tous les doigts sont partis.
    private var tainted = false
    private var pending: (side: TrackpadSide, time: TimeInterval)?

    /// Date à laquelle le tap simple en attente doit partir, s'il y en a un.
    var pendingDeadline: TimeInterval? { pending.map { $0.time + doubleTapGap } }

    mutating func ingest(_ touches: [TrackpadTouch], at time: TimeInterval) -> [EdgeTap] {
        var emitted = flushExpired(at: time)

        if touches.isEmpty {
            if let finished = candidate, !tainted, time - finished.startTime <= maxDuration {
                emitted += register(side: finished.side, at: time)
            }
            candidate = nil
            tainted = false
            return emitted
        }

        guard touches.count == 1, let touch = touches.first else {
            candidate = nil
            tainted = true
            return emitted
        }

        if tainted { return emitted }

        guard let current = candidate else {
            let side: TrackpadSide?
            if touch.x < edgeZone { side = .left } else if touch.x > 1 - edgeZone { side = .right } else { side = nil }
            if let side, touch.size <= maxSize {
                candidate = Candidate(id: touch.id, startTime: time, startX: touch.x, startY: touch.y, side: side)
            } else {
                tainted = true
            }
            return emitted
        }

        let moved = max(abs(touch.x - current.startX), abs(touch.y - current.startY))
        if touch.id != current.id || moved > maxMovement || touch.size > maxSize
            || time - current.startTime > maxDuration {
            candidate = nil
            tainted = true
        }
        return emitted
    }

    /// Fait avancer l'horloge sans nouvelle frame : libère le tap simple dont le délai est écoulé.
    mutating func advance(to time: TimeInterval) -> [EdgeTap] {
        flushExpired(at: time)
    }

    private mutating func flushExpired(at time: TimeInterval) -> [EdgeTap] {
        guard let waiting = pending, time - waiting.time > doubleTapGap else { return [] }
        pending = nil
        return [EdgeTap(side: waiting.side, count: 1)]
    }

    private mutating func register(side: TrackpadSide, at time: TimeInterval) -> [EdgeTap] {
        if let waiting = pending {
            if waiting.side == side {
                pending = nil
                return [EdgeTap(side: side, count: 2)]
            }
            // Autre côté : le tap en attente est un simple, qui part avant le nouveau.
            pending = nil
            return [EdgeTap(side: waiting.side, count: 1)] + register(side: side, at: time)
        }
        if doubleTapSides.contains(side) {
            pending = (side, time)
            return []
        }
        return [EdgeTap(side: side, count: 1)]
    }
}

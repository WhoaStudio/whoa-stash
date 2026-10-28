import Foundation
import Testing

@testable import whoa_stash

/// Classement des taps de bord : le temps est fourni à la main, aucun minuteur réel.
struct EdgeTapClassifierTests {

    private static func touch(_ x: Float, y: Float = 0.5, id: Int32 = 1, size: Float = 0.5) -> TrackpadTouch {
        TrackpadTouch(id: id, x: x, y: y, size: size)
    }

    /// Un tap : pose à `start`, relevé `duration` plus tard.
    private static func tap(_ classifier: inout EdgeTapClassifier, x: Float, at start: TimeInterval,
                            duration: TimeInterval = 0.08) -> [EdgeTap] {
        _ = classifier.ingest([touch(x)], at: start)
        return classifier.ingest([], at: start + duration)
    }

    @Test("un tap court sur le bord gauche donne un tap simple à gauche")
    func leftSingleTap() {
        var classifier = EdgeTapClassifier()
        #expect(Self.tap(&classifier, x: 0.05, at: 0) == [EdgeTap(side: .left, count: 1)])
    }

    @Test("un tap court sur le bord droit donne un tap simple à droite")
    func rightSingleTap() {
        var classifier = EdgeTapClassifier()
        #expect(Self.tap(&classifier, x: 0.95, at: 0) == [EdgeTap(side: .right, count: 1)])
    }

    @Test("un tap au milieu du trackpad est ignoré")
    func middleIsIgnored() {
        var classifier = EdgeTapClassifier()
        #expect(Self.tap(&classifier, x: 0.5, at: 0).isEmpty)
    }

    @Test("un contact trop long est rejeté")
    func tooLongIsRejected() {
        var classifier = EdgeTapClassifier()
        #expect(Self.tap(&classifier, x: 0.05, at: 0, duration: 0.6).isEmpty)
    }

    @Test("un contact qui bouge est rejeté")
    func movedIsRejected() {
        var classifier = EdgeTapClassifier()
        _ = classifier.ingest([Self.touch(0.05)], at: 0)
        _ = classifier.ingest([Self.touch(0.05, y: 0.7)], at: 0.04)
        #expect(classifier.ingest([], at: 0.08).isEmpty)
    }

    @Test("plusieurs doigts annulent le tap")
    func multiTouchIsRejected() {
        var classifier = EdgeTapClassifier()
        _ = classifier.ingest([Self.touch(0.05)], at: 0)
        _ = classifier.ingest([Self.touch(0.05), Self.touch(0.5, id: 2)], at: 0.03)
        #expect(classifier.ingest([], at: 0.08).isEmpty)
    }

    @Test("une paume (contact trop large) est rejetée")
    func palmIsRejected() {
        var classifier = EdgeTapClassifier()
        _ = classifier.ingest([Self.touch(0.05, size: 5)], at: 0)
        #expect(classifier.ingest([], at: 0.08).isEmpty)
    }

    @Test("le rejet d'un contact n'empêche pas le tap suivant")
    func rejectionDoesNotStick() {
        var classifier = EdgeTapClassifier()
        _ = Self.tap(&classifier, x: 0.05, at: 0, duration: 0.6)
        #expect(Self.tap(&classifier, x: 0.05, at: 1) == [EdgeTap(side: .left, count: 1)])
    }

    @Test("deux taps rapprochés du même côté donnent un double tap, sans tap simple")
    func doubleTapCancelsSingle() {
        var classifier = EdgeTapClassifier()
        classifier.doubleTapSides = [.left]
        #expect(Self.tap(&classifier, x: 0.05, at: 0).isEmpty)
        #expect(Self.tap(&classifier, x: 0.05, at: 0.2) == [EdgeTap(side: .left, count: 2)])
        #expect(classifier.advance(to: 2).isEmpty)
    }

    @Test("sans second tap, le tap simple en attente part après le délai")
    func pendingSingleFlushes() {
        var classifier = EdgeTapClassifier()
        classifier.doubleTapSides = [.right]
        #expect(Self.tap(&classifier, x: 0.95, at: 0).isEmpty)
        #expect(classifier.advance(to: 0.2).isEmpty)
        #expect(classifier.advance(to: 0.6) == [EdgeTap(side: .right, count: 1)])
    }

    @Test("deux taps de côtés différents restent deux taps simples")
    func differentSidesStaySingle() {
        var classifier = EdgeTapClassifier()
        classifier.doubleTapSides = [.left, .right]
        _ = Self.tap(&classifier, x: 0.05, at: 0)
        let second = Self.tap(&classifier, x: 0.95, at: 0.15)
        #expect(second == [EdgeTap(side: .left, count: 1)])
        #expect(classifier.advance(to: 1) == [EdgeTap(side: .right, count: 1)])
    }

    @Test("un second tap trop tardif ne fait pas un double tap")
    func lateSecondTapIsNotDouble() {
        var classifier = EdgeTapClassifier()
        classifier.doubleTapSides = [.left]
        _ = Self.tap(&classifier, x: 0.05, at: 0)
        // Le premier tap part dès que le second se pose, puis le second attend à son tour.
        let flushed = classifier.ingest([Self.touch(0.05)], at: 0.8)
        #expect(flushed == [EdgeTap(side: .left, count: 1)])
        #expect(classifier.ingest([], at: 0.88).isEmpty)
        #expect(classifier.advance(to: 1.5) == [EdgeTap(side: .left, count: 1)])
    }
}

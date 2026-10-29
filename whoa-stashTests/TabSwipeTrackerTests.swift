import Testing

@testable import whoa_stash

/// Balayage d'onglets : un geste surtout horizontal et assez long change d'onglet, tout le reste
/// (clic, petit mouvement, défilement vertical) ne change rien.
struct TabSwipeTrackerTests {

    @Test func balayageVersLaGaucheVaAuOngletSuivant() {
        var tracker = TabSwipeTracker()
        #expect(tracker.move(dx: -80, dy: 2))
        #expect(tracker.end() == .next)
    }

    @Test func balayageVersLaDroiteVaAuOngletPrecedent() {
        var tracker = TabSwipeTracker()
        tracker.move(dx: 80, dy: 0)
        #expect(tracker.end() == .previous)
    }

    @Test func unClicSansMouvementNeChangeRien() {
        var tracker = TabSwipeTracker()
        #expect(tracker.end() == nil)
    }

    @Test func unPetitMouvementResteUnClic() {
        var tracker = TabSwipeTracker()
        #expect(!tracker.move(dx: -3, dy: 1))
        #expect(tracker.end() == nil)
    }

    @Test func unBalayageTropCourtNeChangePasDOnglet() {
        var tracker = TabSwipeTracker()
        #expect(tracker.move(dx: -30, dy: 0))
        #expect(tracker.end() == nil)
    }

    @Test func unDefilementVerticalEstAbandonne() {
        var tracker = TabSwipeTracker()
        #expect(!tracker.move(dx: -4, dy: 40))
        // Même si le doigt dérive ensuite vers le côté, le geste reste un défilement.
        #expect(!tracker.move(dx: -200, dy: 0))
        #expect(tracker.end() == nil)
    }

    @Test func leSuiveurEstRemisAZeroApresLeRelache() {
        var tracker = TabSwipeTracker()
        tracker.move(dx: -80, dy: 0)
        _ = tracker.end()
        #expect(tracker.end() == nil)
        #expect(tracker.offset == 0)
    }

    @Test func lOngletVoisinNeReboucleJamais() {
        #expect(NotchTab.global.neighbor(.previous) == nil)
        #expect(NotchTab.ai.neighbor(.next) == nil)
        #expect(NotchTab.global.neighbor(.next) == .calendar)
        #expect(NotchTab.ai.neighbor(.previous) == .mirror)
    }
}

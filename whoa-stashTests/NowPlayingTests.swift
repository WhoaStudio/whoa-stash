import Foundation
import Testing

@testable import whoa_stash

@MainActor
struct NowPlayingParserTests {

    private func line(_ json: String) -> Data { Data(json.utf8) }

    @Test("une ligne complète donne l'état de lecture")
    func parsesFullPayload() {
        var parser = NowPlayingStreamParser()
        let state = parser.ingest(line: line("""
            {"type":"data","diff":false,"payload":{"title":"Titre","artist":"Artiste","playing":true,\
            "bundleIdentifier":"com.spotify.client","artworkData":"aGVsbG8="}}
            """))
        #expect(state == .some(NowPlayingState(
            title: "Titre", artist: "Artiste", artwork: Data("hello".utf8), isPlaying: true,
            bundleIdentifier: "com.spotify.client")))
    }

    @Test("une différence fusionne ses clés dans l'état précédent")
    func mergesDiff() {
        var parser = NowPlayingStreamParser()
        _ = parser.ingest(line: line("""
            {"diff":false,"payload":{"title":"T","artist":"A","playing":true,"bundleIdentifier":"b"}}
            """))
        let paused = parser.ingest(line: line(#"{"diff":true,"payload":{"playing":false}}"#))
        #expect(paused??.isPlaying == false)
        #expect(paused??.title == "T")
    }

    @Test("une clé à null est retirée de l'état")
    func nullRemovesKey() {
        var parser = NowPlayingStreamParser()
        _ = parser.ingest(line: line("""
            {"diff":false,"payload":{"title":"T","artist":"A","playing":true,"bundleIdentifier":"b"}}
            """))
        let state = parser.ingest(line: line(#"{"diff":true,"payload":{"artist":null}}"#))
        #expect(state??.artist == "")
    }

    @Test("sans titre, sans lecteur ou sans clé, il n'y a rien à montrer")
    func missingMandatoryKeys() {
        var parser = NowPlayingStreamParser()
        #expect(parser.ingest(line: line(#"{"diff":false,"payload":{}}"#)) == .some(nil))
        #expect(parser.ingest(line: line(#"{"diff":false,"payload":{"title":"T","playing":true}}"#)) == .some(nil))
    }

    @Test("une ligne illisible ne change rien")
    func ignoresGarbage() {
        var parser = NowPlayingStreamParser()
        #expect(parser.ingest(line: line("pas du json")) == nil)
    }
}

@MainActor
struct NowPlayingViewModelTests {

    private func state(playing: Bool, title: String = "T") -> NowPlayingState {
        NowPlayingState(title: title, artist: "A", artwork: nil, isPlaying: playing, bundleIdentifier: "b")
    }

    private final class RecordingProvider: NowPlayingProviding {
        var onUpdate: ((NowPlayingState?) -> Void)?
        var sent: [NowPlayingCommand] = []
        init() {}
        func start() {}
        func stop() {}
        func send(_ command: NowPlayingCommand) { sent.append(command) }
    }

    @Test("la vue apparaît dès que ça joue et se masque après le délai d'arrêt")
    func hidesAfterDelay() async throws {
        let model = NowPlayingViewModel(provider: RecordingProvider(), hideDelay: .milliseconds(50))
        var emitted: [NowPlayingState?] = []
        model.onStateChanged = { emitted.append($0) }

        model.receive(state(playing: true))
        #expect(emitted == [state(playing: true)])

        model.receive(nil)
        #expect(emitted.count == 1)
        try await Task.sleep(for: .milliseconds(150))
        #expect(emitted.count == 2)
        #expect(emitted[1] == nil)
    }

    @Test("une pause garde le titre affiché le temps du délai, et reprendre annule le masquage")
    func resumeCancelsHide() async throws {
        let model = NowPlayingViewModel(provider: RecordingProvider(), hideDelay: .milliseconds(80))
        var emitted: [NowPlayingState?] = []
        model.onStateChanged = { emitted.append($0) }

        model.receive(state(playing: true))
        model.receive(state(playing: false))
        #expect(emitted.last == .some(state(playing: false)))

        model.receive(state(playing: true))
        try await Task.sleep(for: .milliseconds(200))
        #expect(emitted.last == .some(state(playing: true)))
    }

    @Test("les commandes passent au fournisseur")
    func forwardsCommands() {
        let provider = RecordingProvider()
        let model = NowPlayingViewModel(provider: provider)
        model.send(.nextTrack)
        #expect(provider.sent == [.nextTrack])
    }
}

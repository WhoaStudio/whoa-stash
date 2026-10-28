import Foundation

/// Source des frames tactiles du trackpad. Derrière un protocole pour pouvoir vérifier l'UI
/// sans trackpad ni framework privé (`MockTrackpadTouchProvider`).
protocol TrackpadTouchProviding: AnyObject {
    /// Appelé sur le main thread avec les doigts actuellement posés (vide = tout relevé).
    var onFrame: (([TrackpadTouch]) -> Void)? { get set }
    func start()
    func stop()
}

/// Simule un tap de bord au lancement : `--edge-tap=left-single|left-double|right-single|right-double`.
final class MockTrackpadTouchProvider: TrackpadTouchProviding {

    var onFrame: (([TrackpadTouch]) -> Void)?
    private let side: TrackpadSide
    private let taps: Int

    init(side: TrackpadSide, taps: Int) {
        self.side = side
        self.taps = taps
    }

    static func fromLaunchArguments() -> MockTrackpadTouchProvider? {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--edge-tap=") }) else { return nil }
        let parts = arg.dropFirst("--edge-tap=".count).split(separator: "-").map(String.init)
        guard parts.count == 2, let side = TrackpadSide(rawValue: parts[0]) else { return nil }
        return MockTrackpadTouchProvider(side: side, taps: parts[1] == "double" ? 2 : 1)
    }

    func start() {
        let x: Float = side == .left ? 0.05 : 0.95
        let touch = TrackpadTouch(id: 1, x: x, y: 0.5, size: 0.5)
        for index in 0..<taps {
            let base = 1.5 + Double(index) * 0.2
            DispatchQueue.main.asyncAfter(deadline: .now() + base) { [weak self] in self?.onFrame?([touch]) }
            DispatchQueue.main.asyncAfter(deadline: .now() + base + 0.08) { [weak self] in self?.onFrame?([]) }
        }
    }

    func stop() {}
}

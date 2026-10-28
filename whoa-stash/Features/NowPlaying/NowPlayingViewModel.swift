import Foundation

/// Décide quand la vue « Now Playing » est visible : tant que quelque chose joue, puis encore
/// `hideDelay` après l'arrêt ou la pause, pour qu'une pause depuis l'encoche ne la fasse pas
/// disparaître sous le doigt. Pousse l'état par `onStateChanged` (`nil` = masquer) ; ne tient
/// aucun contrôleur.
final class NowPlayingViewModel {

    var onStateChanged: ((NowPlayingState?) -> Void)?

    private let provider: NowPlayingProviding
    private let hideDelay: Duration
    private var hideTask: Task<Void, Never>?
    private(set) var state: NowPlayingState?

    init(provider: NowPlayingProviding, hideDelay: Duration = .seconds(5)) {
        self.provider = provider
        self.hideDelay = hideDelay
    }

    func activate() {
        provider.onUpdate = { [weak self] update in self?.receive(update) }
        provider.start()
    }

    func send(_ command: NowPlayingCommand) {
        provider.send(command)
    }

    func receive(_ update: NowPlayingState?) {
        if let update, update.isPlaying {
            hideTask?.cancel()
            hideTask = nil
            publish(update)
            return
        }

        // En pause on garde le titre à l'écran (visualiseur arrêté) ; sans plus aucune session
        // il n'y a rien de neuf à montrer, la dernière image reste jusqu'au masquage.
        if let update { publish(update) }
        scheduleHide()
    }

    private func publish(_ update: NowPlayingState) {
        guard update != state else { return }
        state = update
        onStateChanged?(update)
    }

    private func scheduleHide() {
        guard hideTask == nil, state != nil else { return }
        hideTask = Task { [weak self, hideDelay] in
            try? await Task.sleep(for: hideDelay)
            guard !Task.isCancelled, let self else { return }
            hideTask = nil
            state = nil
            onStateChanged?(nil)
        }
    }
}

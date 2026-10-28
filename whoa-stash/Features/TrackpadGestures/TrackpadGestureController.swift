import AppKit
import Combine

/// Branche la source tactile sur le classifieur, puis sur l'exécuteur d'actions, selon les
/// réglages. Ne possède aucune fenêtre ; `apply(settings:)` est rappelé à chaque changement.
final class TrackpadGestureController {

    private let provider: TrackpadTouchProviding
    private let performer: EdgeTapActionPerformer
    private var classifier = EdgeTapClassifier()
    private var settings = TrackpadGestureSettings()
    private var running = false
    private var flushTask: Task<Void, Never>?
    private var wakeCancellable: AnyCancellable?

    init(provider: TrackpadTouchProviding = MultitouchTrackpadProvider(),
         performer: EdgeTapActionPerformer = EdgeTapActionPerformer()) {
        self.provider = provider
        self.performer = performer
        provider.onFrame = { [weak self] touches in self?.receive(touches) }
        // Les appareils tactiles perdent leur flux au réveil : on repart de zéro.
        wakeCancellable = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                guard let self, self.running else { return }
                self.provider.stop()
                self.provider.start()
            }
    }

    var onNowPlayingCommand: ((NowPlayingCommand) -> Void)? {
        get { performer.onNowPlayingCommand }
        set { performer.onNowPlayingCommand = newValue }
    }

    func apply(settings: TrackpadGestureSettings) {
        self.settings = settings
        classifier.doubleTapSides = settings.sidesWithDoubleTap
        if settings.requiresAccessibility, !AccessibilityPermissionService.shared.isTrusted {
            AccessibilityPermissionService.shared.requestAccess()
        }
        if settings.enabled, !running {
            provider.start()
            running = true
        } else if !settings.enabled, running {
            provider.stop()
            running = false
            flushTask?.cancel()
        }
    }

    private func receive(_ touches: [TrackpadTouch]) {
        let now = ProcessInfo.processInfo.systemUptime
        handle(classifier.ingest(touches, at: now))
        scheduleFlush()
    }

    /// Libère le tap simple en attente quand le délai de double tap est écoulé.
    private func scheduleFlush() {
        flushTask?.cancel()
        guard let deadline = classifier.pendingDeadline else { return }
        let delay = max(0, deadline - ProcessInfo.processInfo.systemUptime) + 0.01
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.handle(self.classifier.advance(to: ProcessInfo.processInfo.systemUptime))
        }
    }

    private func handle(_ taps: [EdgeTap]) {
        for tap in taps {
            performer.perform(settings.action(side: tap.side, taps: tap.count))
        }
    }
}

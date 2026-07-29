import AppKit

/// Retour sensoriel joué à chaque graduation franchie. Abstraction au même titre que
/// `BrightnessControlling`, pour pouvoir couper le bruit/haptique en tests ou en preview.
@MainActor
protocol BrightnessFeedback {
    func tickCrossed()
}

/// Un tick sonore très court (son système "Pop") et un tick haptique `.levelChange`,
/// le même vocabulaire que les réglages système (volume, luminosité au clavier) — chacun
/// désactivable indépendamment via `General > Enable haptic/sound feedback`.
final class SystemBrightnessFeedback: BrightnessFeedback {
    private let sound: NSSound?

    init() {
        sound = NSSound(named: "Pop")
        sound?.volume = 0.35
    }

    func tickCrossed() {
        let general = SettingsStorage.shared.settings.general
        if general.enableHapticFeedback {
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        if general.enableSoundFeedback {
            sound?.stop()
            sound?.play()
        }
    }
}

/// Aucun retour — développement, previews, tests.
final class NoOpBrightnessFeedback: BrightnessFeedback {
    func tickCrossed() {}
}

import Combine
import Foundation

/// Expose la section "Trackpad" à sa vue — miroir de `BrightnessSettingsViewModel`.
@MainActor
final class TrackpadSettingsViewModel: ObservableObject {

    private let storage: SettingsStorage
    private var cancellable: AnyCancellable?

    @Published private(set) var settings: TrackpadGestureSettings

    init(storage: SettingsStorage = .shared) {
        self.storage = storage
        self.settings = storage.settings.trackpad

        cancellable = storage.$settings
            .map(\.trackpad)
            .removeDuplicates()
            .sink { [weak self] in self?.settings = $0 }
    }

    func setEnabled(_ enabled: Bool) {
        storage.settings.trackpad.enabled = enabled
    }

    func setAction(_ action: EdgeTapAction, side: TrackpadSide, taps: Int) {
        switch (side, taps) {
        case (.left, 1): storage.settings.trackpad.leftSingle = action
        case (.left, _): storage.settings.trackpad.leftDouble = action
        case (.right, 1): storage.settings.trackpad.rightSingle = action
        case (.right, _): storage.settings.trackpad.rightDouble = action
        }
    }
}

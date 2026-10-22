import Foundation

/// Abstraction du contrôle de luminosité — permet d'échanger facilement
/// une implémentation factice (développement) contre une implémentation système.
protocol BrightnessControlling: AnyObject {
    var brightness: Float { get set }
}

/// Implémentation factice pour le développement et les previews SwiftUI.
/// Ne pilote aucun matériel : garde simplement la valeur en mémoire.
final class FakeBrightnessService: BrightnessControlling {
    var brightness: Float

    init(initialBrightness: Float = 0.6) {
        self.brightness = initialBrightness
    }
}

import CoreGraphics
import Foundation

/// Bas niveau : lit/écrit la luminosité d'un écran précis. `SystemBrightnessService`
/// choisit le bon backend selon l'écran ciblé — aujourd'hui uniquement l'écran interne
/// via `DisplayServicesBackend`. Un futur `DDCBackend` (I2C/DDC via IOKit) pourrait
/// implémenter ce même protocole pour les écrans externes, sans toucher au reste de
/// l'architecture (`BrightnessControlling`, `BrightnessViewModel`).
protocol DisplayBrightnessBackend {
    func brightness(for displayID: CGDirectDisplayID) -> Float?
    @discardableResult func setBrightness(_ value: Float, for displayID: CGDirectDisplayID) -> Bool
}

/// Pilote la luminosité via l'API privée DisplayServices
/// (`/System/Library/PrivateFrameworks/DisplayServices.framework`).
///
/// Il n'existe pas d'API publique pour régler la luminosité native d'un Mac
/// (en particulier sur Apple Silicon, où l'ancienne route IODisplay ne fonctionne plus).
/// DisplayServices est l'API utilisée en interne par le Centre de contrôle et par des
/// outils open-source connus (ex. `nriley/brightness`). C'est la route la plus fiable
/// pour l'écran interne d'un Mac ; elle ne fonctionne en revanche pas de façon fiable
/// pour la plupart des écrans externes tiers, qui nécessitent du DDC/CI (I2C) — hors
/// scope ici, voir `DisplayBrightnessBackend`.
final class DisplayServicesBackend: DisplayBrightnessBackend {

    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let getBrightnessFn: GetBrightnessFn?
    private let setBrightnessFn: SetBrightnessFn?

    init() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_NOW
        ) else {
            print("DisplayServicesBackend: impossible de charger DisplayServices.framework")
            getBrightnessFn = nil
            setBrightnessFn = nil
            return
        }

        if let symbol = dlsym(handle, "DisplayServicesGetBrightness") {
            getBrightnessFn = unsafeBitCast(symbol, to: GetBrightnessFn.self)
        } else {
            getBrightnessFn = nil
        }

        if let symbol = dlsym(handle, "DisplayServicesSetBrightness") {
            setBrightnessFn = unsafeBitCast(symbol, to: SetBrightnessFn.self)
        } else {
            setBrightnessFn = nil
        }
    }

    func brightness(for displayID: CGDirectDisplayID) -> Float? {
        guard let getBrightnessFn else { return nil }
        var value: Float = 0
        guard getBrightnessFn(displayID, &value) == 0 else { return nil }
        return value
    }

    @discardableResult
    func setBrightness(_ value: Float, for displayID: CGDirectDisplayID) -> Bool {
        guard let setBrightnessFn else { return false }
        return setBrightnessFn(displayID, max(0, min(1, value))) == 0
    }
}

/// Implémentation concrète de `BrightnessControlling` exposée à l'app. Cible aujourd'hui
/// l'écran principal (`CGMainDisplayID`, généralement l'écran interne sur un MacBook) via
/// `DisplayServicesBackend`. Le `displayID` est injectable pour permettre, plus tard, de
/// router vers un autre backend selon le type d'écran (ex. `CGDisplayIsBuiltin` pour choisir
/// entre DisplayServices et un futur backend DDC).
final class SystemBrightnessService: BrightnessControlling {

    private let backend: DisplayBrightnessBackend
    private let displayID: () -> CGDirectDisplayID

    init(backend: DisplayBrightnessBackend = DisplayServicesBackend(), displayID: @escaping () -> CGDirectDisplayID = CGMainDisplayID) {
        self.backend = backend
        self.displayID = displayID
    }

    var brightness: Float {
        get { backend.brightness(for: displayID()) ?? 0.5 }
        set { backend.setBrightness(newValue, for: displayID()) }
    }
}

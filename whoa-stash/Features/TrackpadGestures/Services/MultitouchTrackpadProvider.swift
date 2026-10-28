import AppKit
import OSLog

/// Frames tactiles globales via `MultitouchSupport.framework` (privé), chargé par
/// `dlopen`/`dlsym` comme `DDCTransport` : absent ou modifié, l'app dégrade sans planter.
///
/// Le callback tourne sur un thread du framework. Il lit les `MTTouch` à des décalages fixes
/// (struct de 96 octets : identifiant en 16, position normalisée en 32, taille en 48) et
/// repasse sur le main thread.
final class MultitouchTrackpadProvider: TrackpadTouchProviding {

    var onFrame: (([TrackpadTouch]) -> Void)? {
        get { Self.sink.value }
        set { Self.sink.value = newValue }
    }

    private typealias CreateListFn = @convention(c) () -> Unmanaged<CFArray>?
    private typealias CallbackFn = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
    private typealias RegisterFn = @convention(c) (UnsafeMutableRawPointer, CallbackFn) -> Void
    private typealias StartFn = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
    private typealias StopFn = @convention(c) (UnsafeMutableRawPointer) -> Void

    private var devices: [UnsafeMutableRawPointer] = []
    private var stopFn: StopFn?

    func start() {
        guard devices.isEmpty else { return }
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW),
              let createSymbol = dlsym(handle, "MTDeviceCreateList"),
              let registerSymbol = dlsym(handle, "MTRegisterContactFrameCallback"),
              let startSymbol = dlsym(handle, "MTDeviceStart"),
              let stopSymbol = dlsym(handle, "MTDeviceStop")
        else {
            Log.trackpad.error("MultitouchSupport indisponible : taps de bord désactivés")
            return
        }
        let create = unsafeBitCast(createSymbol, to: CreateListFn.self)
        let register = unsafeBitCast(registerSymbol, to: RegisterFn.self)
        let startDevice = unsafeBitCast(startSymbol, to: StartFn.self)
        stopFn = unsafeBitCast(stopSymbol, to: StopFn.self)

        guard let list = create()?.takeRetainedValue() else { return }
        let callback = Self.callback
        for index in 0..<CFArrayGetCount(list) {
            guard let device = CFArrayGetValueAtIndex(list, index) else { continue }
            let pointer = UnsafeMutableRawPointer(mutating: device)
            // Le framework garde la référence : on retient la liste en retenant chaque appareil.
            _ = Unmanaged<AnyObject>.fromOpaque(pointer).retain()
            register(pointer, callback)
            startDevice(pointer, 0)
            devices.append(pointer)
        }
        Log.trackpad.info("Taps de bord : \(self.devices.count, privacy: .public) trackpad(s)")
    }

    func stop() {
        for device in devices {
            stopFn?(device)
            Unmanaged<AnyObject>.fromOpaque(device).release()
        }
        devices.removeAll()
    }

    // MARK: - Thread du framework

    private nonisolated final class Sink: @unchecked Sendable {
        private let lock = NSLock()
        private var handler: (([TrackpadTouch]) -> Void)?
        var value: (([TrackpadTouch]) -> Void)? {
            get { lock.withLock { handler } }
            set { lock.withLock { handler = newValue } }
        }
    }

    private nonisolated static let sink = Sink()
    private nonisolated static let touchStride = 96
    private nonisolated static let callback: CallbackFn = { _, data, count, _, _ in
        handle(data: data, count: Int(count))
        return 0
    }

    private nonisolated static func handle(data: UnsafeMutableRawPointer?, count: Int) {
        var touches: [TrackpadTouch] = []
        if let data, count > 0 {
            for index in 0..<count {
                let base = data + index * touchStride
                touches.append(TrackpadTouch(
                    id: base.load(fromByteOffset: 16, as: Int32.self),
                    x: base.load(fromByteOffset: 32, as: Float.self),
                    y: base.load(fromByteOffset: 36, as: Float.self),
                    size: base.load(fromByteOffset: 48, as: Float.self)))
            }
        }
        DispatchQueue.main.async { sink.value?(touches) }
    }
}

import AppKit

extension NSScreen {
    /// Identifiant matériel de l'écran, stable contrairement à sa position dans
    /// `NSScreen.screens` : cette position change dès qu'un écran est branché ou débranché,
    /// donc tout ce qui doit survivre à un changement de configuration s'indexe là-dessus.
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}

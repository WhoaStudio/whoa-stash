import AppKit
import ApplicationServices

/// Dit si le Dock macOS est à l'écran en ce moment. Son cadre Accessibilité (la liste d'icônes
/// enfant du processus Dock) sort de l'écran quand il est masqué ; sa fenêtre, elle, couvre
/// toujours tout l'écran et ne dit rien.
@MainActor
enum SystemDockVisibility {

    /// `nil` quand on ne peut pas le savoir (Accessibilité refusée, Dock introuvable).
    static func isVisible() -> Bool? {
        guard AXIsProcessTrusted(),
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first,
              let screen = NSScreen.screens.first
        else { return nil }
        let element = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.2)
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
              let list = children as? [AXUIElement], let first = list.first
        else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(first, kAXPositionAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        var origin = CGPoint.zero
        guard AXValueGetValue(value as! AXValue, .cgPoint, &origin) else { return nil }
        // Repère Accessibilité : origine en haut à gauche de l'écran principal. Masqué, le haut du
        // Dock est au bas de l'écran ou en dessous.
        return origin.y < screen.frame.height - 1
    }
}

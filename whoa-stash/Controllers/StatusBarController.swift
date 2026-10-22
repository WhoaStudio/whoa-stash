import AppKit
import OSLog

/// Gère l'icône dans la menu bar macOS (NSStatusItem) et son menu déroulant.
@MainActor
final class StatusBarController {

    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            let icon = NSImage(named: "AppIcon")
            icon?.size = NSSize(width: 18, height: 18)
            icon?.isTemplate = false
            icon?.accessibilityDescription = "Whoa Stash"
            button.image = icon
        }

        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        menu.addItem(
            NSMenuItem(
                title: "Préférences…",
                action: #selector(openPreferences),
                keyEquivalent: ","
            )
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit Whoa Stash",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )

        for item in menu.items where item.action == #selector(openPreferences) {
            item.target = self
        }

        statusItem.menu = menu
    }

    @objc private func openPreferences() {
        Log.settings.debug("ouverture de la fenêtre de Préférences")
        SettingsWindowController.shared.show()
    }
}

import Carbon.HIToolbox
import Foundation
import OSLog

/// Enregistre le raccourci global auprès du système et appelle `onTrigger` quand il est frappé.
///
/// Passe par `RegisterEventHotKey` (Carbon) et non par `NSEvent.addGlobalMonitorForEvents` :
/// un moniteur global exige l'autorisation de surveillance de la saisie, un hot key enregistré
/// n'exige rien. C'est aussi lui qui fait que la combinaison est réservée — macOS ne la livre
/// plus à l'app de premier plan tant qu'on la détient.
@MainActor
final class GlobalShortcutService {

    static let shared = GlobalShortcutService()

    /// Appelé sur la boucle principale à chaque frappe du raccourci enregistré.
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var current: GlobalShortcut = .disabled

    /// Identifiant arbitraire mais stable : un seul raccourci est détenu à la fois, et c'est lui
    /// qu'on reconnaît dans le handler.
    private static let hotKeyID: UInt32 = 0x5748_4F41  // 'WHOA'

    private init() {}

    /// Idempotent : réappliquer le même raccourci ne déséenregistre rien. Appelé à chaque
    /// changement du réglage, donc il doit être sûr à répétition.
    func apply(_ shortcut: GlobalShortcut) {
        guard shortcut != current else { return }
        current = shortcut

        unregisterHotKey()
        guard let keyCode = shortcut.keyCode else {
            Log.settings.info("raccourci global désactivé")
            return
        }

        installHandlerIfNeeded()

        let id = EventHotKeyID(signature: OSType(Self.hotKeyID), id: Self.hotKeyID)
        let status = RegisterEventHotKey(
            keyCode,
            shortcut.carbonModifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            Log.settings.info("raccourci global enregistré → \(shortcut.displayName, privacy: .public)")
        } else {
            // Le plus souvent : la combinaison est déjà détenue par le système ou une autre app.
            hotKeyRef = nil
            Log.settings.error(
                "échec de l'enregistrement du raccourci \(shortcut.displayName, privacy: .public) — code \(status, privacy: .public)"
            )
        }
    }

    private func unregisterHotKey() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    /// Le handler Carbon est posé une seule fois pour la durée de vie du service : seul le hot
    /// key lui-même est enregistré et retiré au fil des changements de réglage.
    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Le callback est une fonction C : il ne capture rien et repasse par le singleton.
        let callback: EventHandlerUPP = { _, event, _ in
            var id = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &id
            )
            guard status == noErr, id.id == GlobalShortcutService.hotKeyID else { return OSStatus(eventNotHandledErr) }

            MainActor.assumeIsolated {
                GlobalShortcutService.shared.onTrigger?()
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, nil, &handlerRef)
    }
}

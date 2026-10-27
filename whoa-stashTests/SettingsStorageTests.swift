import Foundation
import Testing

@testable import whoa_stash

/// Persistance des préférences. `SettingsStorage` accepte un `UserDefaults` injecté, donc
/// chaque test travaille dans sa propre suite nommée, jamais dans `.standard` : rien ne fuit
/// d'un test à l'autre ni dans les réglages réels de la machine.
@MainActor
struct SettingsStorageTests {

    /// Un `UserDefaults` vierge, isolé par test, effacé en fin de portée.
    private static func makeDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "whoa-stash.tests.\(name)")!
        defaults.removePersistentDomain(forName: "whoa-stash.tests.\(name)")
        return defaults
    }

    @Test("une suite vide rend les valeurs par défaut")
    func emptyDefaultsYieldDefaultSettings() {
        let storage = SettingsStorage(defaults: Self.makeDefaults())
        #expect(storage.settings == .default)
    }

    @Test("une écriture survit à une nouvelle instance — le cas du relancement")
    func writesSurviveRelaunch() {
        let defaults = Self.makeDefaults()

        let first = SettingsStorage(defaults: defaults)
        first.settings.general.appearanceMode = .dark
        first.settings.general.accentColor = .purple
        first.settings.brightness.glowIntensity = 1.6
        first.settings.notchPanel.enabled = false

        // Deuxième instance sur la même suite : c'est ce que fait un relancement de l'app.
        let second = SettingsStorage(defaults: defaults)
        #expect(second.settings.general.appearanceMode == .dark)
        #expect(second.settings.general.accentColor == .purple)
        #expect(second.settings.brightness.glowIntensity == 1.6)
        #expect(second.settings.notchPanel.enabled == false)
    }

    @Test("un blob illisible retombe sur les valeurs par défaut au lieu de planter")
    func corruptBlobFallsBackToDefaults() {
        let defaults = Self.makeDefaults()
        defaults.set(Data("pas du JSON".utf8), forKey: "com.whoastudio.whoa-stash.appSettings")

        let storage = SettingsStorage(defaults: defaults)
        #expect(storage.settings == .default)
    }

    @Test("un réglage absent du blob garde sa valeur par défaut")
    func missingKeysKeepTheirDefaults() throws {
        let defaults = Self.makeDefaults()
        // Un blob d'une version antérieure, qui ne connaît qu'une partie des réglages.
        let partial = #"{"general":{"appearanceMode":"light"}}"#
        defaults.set(Data(partial.utf8), forKey: "com.whoastudio.whoa-stash.appSettings")

        let storage = SettingsStorage(defaults: defaults)
        #expect(storage.settings.general.appearanceMode == .light)
        // Non écrits par le blob partiel, donc rendus par les valeurs par défaut du modèle.
        #expect(storage.settings.general.enableAnimations == GeneralSettings().enableAnimations)
        #expect(storage.settings.brightness == BrightnessSettings())
    }

    @Test("une valeur d'énumération inconnue retombe sur la valeur par défaut")
    func unknownEnumCaseFallsBack() {
        let defaults = Self.makeDefaults()
        let blob = #"{"general":{"accentColor":"chartreuse","appearanceMode":"dark"}}"#
        defaults.set(Data(blob.utf8), forKey: "com.whoastudio.whoa-stash.appSettings")

        let storage = SettingsStorage(defaults: defaults)
        #expect(storage.settings.general.accentColor == GeneralSettings().accentColor)
        // Le voisin lisible est conservé : un cas inconnu n'emporte pas la section.
        #expect(storage.settings.general.appearanceMode == .dark)
    }

    /// Les réglages ajoutés par cette version : un blob qui les ignore doit garder le reste.
    @Test("un blob antérieur garde ce qu'il porte, les nouveaux réglages prennent leur défaut")
    func olderBlobKeepsWhatItCarries() {
        let defaults = Self.makeDefaults()
        let older = #"{"general":{"launchAtLogin":true,"accentColor":"blue","enableAnimations":false}}"#
        defaults.set(Data(older.utf8), forKey: "com.whoastudio.whoa-stash.appSettings")

        let storage = SettingsStorage(defaults: defaults)
        #expect(storage.settings.general.launchAtLogin == true)
        #expect(storage.settings.general.accentColor == .blue)
        #expect(storage.settings.general.enableAnimations == false)
        // Absents du blob, donc à leur valeur par défaut — et non perdus avec tout le reste.
        #expect(storage.settings.general.panelOpacity == GeneralSettings().panelOpacity)
        #expect(storage.settings.general.togglePanelShortcut == .disabled)
        #expect(storage.settings.brightness == BrightnessSettings())
    }

    @Test("une valeur réécrite à l'identique n'est pas réécrite sur le disque")
    func identicalWriteDoesNotPersistAgain() {
        let suite = "whoa-stash.tests.counting"
        let defaults = CountingDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let storage = SettingsStorage(defaults: defaults)
        storage.settings.general.appearanceMode = .dark
        let afterFirstWrite = defaults.writeCount
        #expect(afterFirstWrite > 0)

        // `SettingsStorage` compare l'ancienne et la nouvelle valeur avant de persister.
        storage.settings.general.appearanceMode = .dark
        #expect(defaults.writeCount == afterFirstWrite)

        storage.settings.general.appearanceMode = .light
        #expect(defaults.writeCount == afterFirstWrite + 1)
    }
}

/// Compte les écritures, pour vérifier que `SettingsStorage` ne persiste pas deux fois la
/// même valeur. `UserDefaults` n'expose rien de tel.
private final class CountingDefaults: UserDefaults {
    private(set) var writeCount = 0

    override func set(_ value: Any?, forKey defaultName: String) {
        writeCount += 1
        super.set(value, forKey: defaultName)
    }
}

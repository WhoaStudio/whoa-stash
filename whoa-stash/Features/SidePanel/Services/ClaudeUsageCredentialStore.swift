import Foundation
import Security

enum ClaudeUsageCredentialError: LocalizedError {
    case notFound
    case unreadable(OSStatus)
    case malformed
    case expired

    var errorDescription: String? {
        switch self {
        case .notFound: return "Claude Code n'est pas connecté sur cette machine."
        case .unreadable(let status): return "Trousseau illisible (OSStatus \(status))."
        case .malformed: return "Jeton Claude Code illisible."
        case .expired: return "Session Claude Code expirée — relance `claude` pour la renouveler."
        }
    }
}

/// Lit le jeton OAuth que Claude Code dépose dans le trousseau de l'utilisateur, sous l'item
/// générique `Claude Code-credentials`.
///
/// L'ACL de cet item appartient au binaire `claude` : à la première lecture, macOS affiche donc
/// une autorisation à accorder une fois pour toutes. Il n'y a rien à faire pour l'éviter — c'est
/// exactement la protection qui empêche n'importe quel process de lire le jeton — et l'app doit
/// rester fonctionnelle si l'utilisateur refuse, d'où `ClaudeUsageState.unavailable`.
///
/// Aucun jeton n'est conservé en mémoire au-delà de la requête qui l'utilise, ni journalisé.
struct ClaudeUsageCredentialStore {

    static let keychainService = "Claude Code-credentials"

    /// Forme du JSON stocké dans l'item : `expiresAt` est un timestamp **en millisecondes**.
    private struct Payload: Decodable {
        struct OAuth: Decodable {
            let accessToken: String
            let expiresAt: Double?
        }
        let claudeAiOauth: OAuth
    }

    func accessToken(now: Date = Date()) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else { throw ClaudeUsageCredentialError.notFound }
        guard status == errSecSuccess, let data = item as? Data else {
            throw ClaudeUsageCredentialError.unreadable(status)
        }

        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw ClaudeUsageCredentialError.malformed
        }

        if let expiresAt = payload.claudeAiOauth.expiresAt {
            let expiry = Date(timeIntervalSince1970: expiresAt / 1000)
            // Marge de 30 s : inutile de partir sur une requête qui sera refusée en vol.
            guard expiry.timeIntervalSince(now) > 30 else { throw ClaudeUsageCredentialError.expired }
        }

        return payload.claudeAiOauth.accessToken
    }
}

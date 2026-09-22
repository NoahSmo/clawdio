import Foundation
import Security

/// Token OAuth que Claude Code range dans le Keychain (`Claude Code-credentials`).
/// Lecture seule : on ne rafraîchit jamais le token nous-mêmes, sinon on invaliderait
/// le refresh token de Claude Code. Claude Code le renouvelle tout seul quand il tourne.
struct ClaudeCredentials {
    let accessToken: String
    let expiresAt: Date?
    let subscriptionType: String?

    static func load() throws -> ClaudeCredentials {
        let data = try readKeychainItem()
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let oauth = root["claudeAiOauth"] as? [String: Any],
            let token = oauth["accessToken"] as? String
        else { throw UsageError.unreadableCredentials }

        // expiresAt = millisecondes depuis epoch
        let expiry = (oauth["expiresAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
        return ClaudeCredentials(
            accessToken: token,
            expiresAt: expiry,
            subscriptionType: oauth["subscriptionType"] as? String
        )
    }

    /// Lecture via `/usr/bin/security` plutôt que `SecItemCopyMatching`.
    ///
    /// Le Trousseau lie l'autorisation "Toujours autoriser" à la *signature* de l'app demandeuse. Or un
    /// build signé ad-hoc change de signature (cdhash) à chaque compilation : macOS redemandait donc
    /// l'autorisation à chaque nouvelle version. `security` est un binaire Apple à signature stable, déjà
    /// autorisé par l'entrée : lecture silencieuse, sans élargir aucun droit d'accès.
    private static func readKeychainItem() throws -> Data {
        if let viaTool = readViaSecurityTool() { return viaTool }
        return try readViaSecItem() // repli : accès direct (peut afficher l'invite du Trousseau)
    }

    private static func readViaSecurityTool() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, !data.isEmpty else { return nil }
        return data
    }

    private static func readViaSecItem() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess: break
        case errSecItemNotFound: throw UsageError.noCredentials
        default: throw UsageError.keychainDenied(status)
        }
        guard let data = item as? Data else { throw UsageError.unreadableCredentials }
        return data
    }
}

import Foundation
import OSLog
import Security

/// La sesión de Supabase en un grupo de Keychain compartido con las extensiones.
///
/// La app es la única que entra y renueva el token; la Share Extension y los App Intents solo leen la sesión guardada
/// (`SupabaseLumbreAPI.borrowingSharedSession`). Antes de usar el grupo se prueba que el proceso tenga el entitlement:
/// si no lo tiene (tests, un build sin App Group) se sigue con el Keychain propio, para no perder la sesión.
enum SharedKeychain {
    /// El mismo `service` que usa `KeychainLocalStorage` de supabase-swift.
    static let service = "supabase.gotrue.swift"

    private static let logger = Logger(subsystem: "com.matiasrodriguezc.lumbre", category: "keychain")

    /// Si este proceso puede escribir en el grupo. Escribe y borra un ítem de prueba.
    static func isAvailable(group: String) -> Bool {
        let probe: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.matiasrodriguezc.lumbre.probe",
            kSecAttrAccount as String: "probe",
            kSecAttrAccessGroup as String: group,
        ]
        var add = probe
        add[kSecValueData as String] = Data("1".utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            logger.notice("Keychain compartido no disponible: \(status, privacy: .public)")
            return false
        }
        SecItemDelete(probe as CFDictionary)
        return true
    }

    /// Mueve la sesión guardada antes en el Keychain propio de la app al grupo compartido, una sola vez.
    /// Primero copia y después borra el original (con su grupo exacto, para no tocar la copia nueva):
    /// si algo falla en el medio, la sesión sigue donde estaba.
    static func migrateSession(key: String, to group: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        var inGroup = base
        inGroup[kSecAttrAccessGroup as String] = group
        inGroup[kSecMatchLimit as String] = kSecMatchLimitOne
        if SecItemCopyMatching(inGroup as CFDictionary, nil) == errSecSuccess { return }

        var legacyQuery = base
        legacyQuery[kSecReturnData as String] = true
        legacyQuery[kSecReturnAttributes as String] = true
        legacyQuery[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(legacyQuery as CFDictionary, &result) == errSecSuccess,
              let attributes = result as? [String: Any],
              let data = attributes[kSecValueData as String] as? Data,
              let legacyGroup = attributes[kSecAttrAccessGroup as String] as? String,
              legacyGroup != group
        else { return }

        var add = base
        add[kSecAttrAccessGroup as String] = group
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            logger.error("No se pudo mover la sesión al Keychain compartido: \(status, privacy: .public)")
            return
        }
        var legacy = base
        legacy[kSecAttrAccessGroup as String] = legacyGroup
        SecItemDelete(legacy as CFDictionary)
        logger.info("Sesión movida al Keychain compartido")
    }

    /// La clave con la que supabase-swift guarda la sesión: `sb-<primer tramo del host>-auth-token`.
    static func storageKey(for url: URL) -> String {
        let host = url.host() ?? url.absoluteString
        return "sb-\(host.split(separator: ".").first.map(String.init) ?? host)-auth-token"
    }
}

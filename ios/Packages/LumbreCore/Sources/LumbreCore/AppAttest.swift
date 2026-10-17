import CryptoKit
import DeviceCheck
import Foundation

/// App Attest del lado de la app (plan.md §5, "Cuotas y abuso"): firma los pedidos a las Edge Functions de IA
/// con una clave que vive en el Secure Enclave, para que el servidor sepa que vienen de la app real.
///
/// Protocolo (provisorio hasta que el servidor lo verifique, paso 40):
/// - `X-Lumbre-Attest-Key`: id de la clave (base64, lo da `DCAppAttestService`).
/// - `X-Lumbre-Attest-Time`: segundos Unix del pedido; el servidor rechaza los viejos (repetidos).
/// - El primer pedido con una clave nueva lleva `X-Lumbre-Attestation` (el objeto CBOR de Apple, en base64);
///   los siguientes, `X-Lumbre-Assertion`. En los dos, `clientDataHash = SHA256("<función>\n<time>\n<cuerpo>")`.
///
/// Donde no hay App Attest (simulador, Mac, sin el entitlement de Apple Developer) no se manda nada y el pedido
/// sigue igual: el servidor decide qué hacer con los pedidos sin firma. Ningún error de App Attest frena a la app.
public actor AppAttestor {
    public enum Header {
        public static let keyID = "X-Lumbre-Attest-Key"
        public static let time = "X-Lumbre-Attest-Time"
        public static let attestation = "X-Lumbre-Attestation"
        public static let assertion = "X-Lumbre-Assertion"
    }

    /// Las Edge Functions que gastan IA (o pueden generarla, como `today`).
    public static let protectedFunctions: Set<String> = ["capture", "today", "spark", "search", "planner"]

    public static let shared = AppAttestor(service: SystemAppAttestService(), store: UserDefaultsAttestKeyStore())

    private let service: any AppAttestService
    private let store: any AttestKeyStore
    private let now: @Sendable () -> Date

    init(service: any AppAttestService, store: any AttestKeyStore, now: @escaping @Sendable () -> Date = { .now }) {
        self.service = service
        self.store = store
        self.now = now
    }

    /// Headers para firmar el pedido. Vacío si App Attest no está disponible o falla.
    public func headers(function: String, body: Data) async -> [String: String] {
        guard Self.protectedFunctions.contains(function), service.isSupported else { return [:] }
        let time = String(Int(now().timeIntervalSince1970))
        let hash = Self.clientDataHash(function: function, time: time, body: body)
        do {
            var key: AttestKey
            if let stored = store.load() {
                key = stored
            } else {
                key = AttestKey(id: try await service.generateKey(), isAttested: false)
                store.save(key)
            }
            var headers = [Header.keyID: key.id, Header.time: time]
            if key.isAttested {
                headers[Header.assertion] = try await service.generateAssertion(key.id, clientDataHash: hash).base64EncodedString()
            } else {
                headers[Header.attestation] = try await service.attestKey(key.id, clientDataHash: hash).base64EncodedString()
                key.isAttested = true
                store.save(key)
            }
            return headers
        } catch let error as DCError where error.code == .invalidKey || error.code == .invalidInput {
            // La clave ya no sirve (restauraron el teléfono, Apple la rechazó): la próxima vez se crea otra.
            store.save(nil)
            LumbreShared.logger.notice("App Attest: clave descartada (\(error.code.rawValue, privacy: .public))")
            return [:]
        } catch {
            // Servidor de Apple caído u otro error pasajero: el pedido sale sin firma.
            LumbreShared.logger.notice("App Attest no disponible: \(String(describing: type(of: error)), privacy: .public)")
            return [:]
        }
    }

    /// Descarta la clave (por ejemplo, si el servidor responde que no la reconoce).
    public func resetKey() {
        store.save(nil)
    }

    static func clientDataHash(function: String, time: String, body: Data) -> Data {
        var data = Data("\(function)\n\(time)\n".utf8)
        data.append(body)
        return Data(SHA256.hash(data: data))
    }
}

// MARK: - Piezas reemplazables (para los tests)

public protocol AppAttestService: Sendable {
    var isSupported: Bool { get }
    func generateKey() async throws -> String
    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data
    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data
}

/// `DCAppAttestService` del sistema. En el simulador `isSupported` es false.
struct SystemAppAttestService: AppAttestService {
    var isSupported: Bool { DCAppAttestService.shared.isSupported }

    func generateKey() async throws -> String {
        try await DCAppAttestService.shared.generateKey()
    }

    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data {
        try await DCAppAttestService.shared.attestKey(keyID, clientDataHash: clientDataHash)
    }

    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
        try await DCAppAttestService.shared.generateAssertion(keyID, clientDataHash: clientDataHash)
    }
}

struct AttestKey: Codable, Equatable, Sendable {
    var id: String
    /// Ya se mandó la atestación con esta clave: de acá en más, solo aserciones.
    var isAttested: Bool
}

protocol AttestKeyStore: Sendable {
    func load() -> AttestKey?
    func save(_ key: AttestKey?)
}

/// El id de la clave no es secreto (la clave privada nunca sale del Secure Enclave). Al reinstalar la app se borra,
/// igual que la validez de la clave.
struct UserDefaultsAttestKeyStore: AttestKeyStore {
    private static let key = "appAttest.key"

    func load() -> AttestKey? {
        guard let data = UserDefaults.standard.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(AttestKey.self, from: data)
    }

    func save(_ value: AttestKey?) {
        if let value, let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: Self.key)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.key)
        }
    }
}

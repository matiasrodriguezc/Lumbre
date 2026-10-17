import DeviceCheck
import Foundation
import Testing
@testable import LumbreCore

/// Cuenta con email: validación local y el recorrido del invitado en el mock.
@Suite struct AccountTests {
    @Test func normalizesEmails() {
        #expect(EmailAccount.normalized("  Ana@Lumbre.TEST ") == "ana@lumbre.test")
        #expect(EmailAccount.normalized("ana@lumbre") == nil)
        #expect(EmailAccount.normalized("ana lumbre@x.com") == nil)
        #expect(EmailAccount.normalized("@lumbre.test") == nil)
        #expect(EmailAccount.normalized("ana@.test") == nil)
    }

    @Test func codesAreSixDigits() {
        #expect(EmailAccount.normalizedCode("123 456") == "123456")
        #expect(EmailAccount.normalizedCode("12345") == nil)
        #expect(EmailAccount.normalizedCode("１２３４５６") == nil)
    }

    @Test func recognizesTheCallback() {
        #expect(EmailAccount.isCallback(URL(string: "lumbre://auth-callback?code=abc")!))
        #expect(EmailAccount.isCallback(URL(string: "lumbre://auth-callback/#access_token=x")!))
        #expect(!EmailAccount.isCallback(URL(string: "lumbre://spark/1")!))
    }

    @Test func guestCreatesAnAccountAndKeepsEverything() async throws {
        let api = MockLumbreAPI(latency: .zero, onboarded: false)
        _ = try await api.capture(thesis: "Idea de invitado", category: "Cocina", source: .text)
        try await api.requestEmailCode("nueva@lumbre.test", purpose: .createAccount)
        let profile = try await api.verifyEmailCode(MockLumbreAPI.emailCode, email: "nueva@lumbre.test", purpose: .createAccount)
        #expect(profile.plan == .free)
        #expect(profile.email == "nueva@lumbre.test")
        #expect(try await api.concepts().map(\.thesis) == ["Idea de invitado"])
    }

    @Test func wrongCodeIsRejected() async throws {
        let api = MockLumbreAPI(latency: .zero, onboarded: false)
        await #expect(throws: LumbreAPIError.invalidCode) {
            _ = try await api.verifyEmailCode("000000", email: "nueva@lumbre.test", purpose: .createAccount)
        }
        #expect(try await api.profile().isGuest)
    }

    @Test func existingEmailCannotBeLinkedToTheGuest() async throws {
        let api = MockLumbreAPI(latency: .zero, onboarded: false)
        await #expect(throws: LumbreAPIError.emailInUse) {
            try await api.requestEmailCode(MockData.existingAccountEmail, purpose: .createAccount)
        }
        await #expect(throws: LumbreAPIError.invalidEmail) {
            try await api.requestEmailCode("no-es-un-email", purpose: .signIn)
        }
    }

    @Test func signingInLoadsTheExistingAccount() async throws {
        let api = MockLumbreAPI(latency: .zero, onboarded: false)
        let profile = try await api.verifyEmailCode(MockLumbreAPI.emailCode, email: MockData.existingAccountEmail, purpose: .signIn)
        #expect(profile.isOnboarded && !profile.isGuest)
        #expect(try await api.concepts().isEmpty == false)
    }
}

// MARK: - App Attest

private final class FakeAttestService: AppAttestService, @unchecked Sendable {
    var isSupported = true
    var keysGenerated = 0
    var attestations = 0
    var assertions = 0
    var failNextAssertion: DCError.Code?

    func generateKey() async throws -> String {
        keysGenerated += 1
        return "key-\(keysGenerated)"
    }

    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data {
        attestations += 1
        return Data("attestation-\(keyID)".utf8)
    }

    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
        if let code = failNextAssertion {
            failNextAssertion = nil
            throw DCError(code)
        }
        assertions += 1
        return Data("assertion-\(keyID)".utf8)
    }
}

private final class MemoryKeyStore: AttestKeyStore, @unchecked Sendable {
    var key: AttestKey?
    func load() -> AttestKey? { key }
    func save(_ key: AttestKey?) { self.key = key }
}

@Suite struct AppAttestTests {
    let body = Data(#"{"mode":"extra"}"#.utf8)

    @Test func firstRequestAttestsThenAsserts() async {
        let service = FakeAttestService()
        let attestor = AppAttestor(service: service, store: MemoryKeyStore(), now: { Date(timeIntervalSince1970: 1_000) })
        let first = await attestor.headers(function: "spark", body: body)
        #expect(first[AppAttestor.Header.keyID] == "key-1")
        #expect(first[AppAttestor.Header.time] == "1000")
        #expect(first[AppAttestor.Header.attestation] != nil)
        #expect(first[AppAttestor.Header.assertion] == nil)

        let second = await attestor.headers(function: "planner", body: body)
        #expect(second[AppAttestor.Header.assertion] == Data("assertion-key-1".utf8).base64EncodedString())
        #expect(second[AppAttestor.Header.attestation] == nil)
        #expect(service.keysGenerated == 1 && service.attestations == 1 && service.assertions == 1)
    }

    @Test func unsupportedDevicesSendNothing() async {
        let service = FakeAttestService()
        service.isSupported = false
        let attestor = AppAttestor(service: service, store: MemoryKeyStore())
        #expect(await attestor.headers(function: "spark", body: body).isEmpty)
        #expect(service.keysGenerated == 0)
    }

    @Test func onlyAIFunctionsAreSigned() async {
        let attestor = AppAttestor(service: FakeAttestService(), store: MemoryKeyStore())
        #expect(await attestor.headers(function: "dev-plan", body: body).isEmpty)
    }

    @Test func invalidKeyIsDiscardedWithoutFailingTheRequest() async {
        let service = FakeAttestService()
        let store = MemoryKeyStore()
        let attestor = AppAttestor(service: service, store: store)
        _ = await attestor.headers(function: "spark", body: body)
        service.failNextAssertion = .invalidKey
        #expect(await attestor.headers(function: "spark", body: body).isEmpty)
        #expect(store.key == nil)
        // La próxima vez arranca con una clave nueva.
        let next = await attestor.headers(function: "spark", body: body)
        #expect(next[AppAttestor.Header.keyID] == "key-2")
        #expect(next[AppAttestor.Header.attestation] != nil)
    }

    @Test func hashCoversFunctionTimeAndBody() {
        let a = AppAttestor.clientDataHash(function: "spark", time: "1", body: body)
        #expect(a.count == 32)
        #expect(a != AppAttestor.clientDataHash(function: "planner", time: "1", body: body))
        #expect(a != AppAttestor.clientDataHash(function: "spark", time: "2", body: body))
    }
}

// MARK: - El servidor rechaza la firma

/// Responde lo que se le pida y anota los headers de cada pedido.
private final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responses: [(Int, String)] = []
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.requests.append(request)
        let (status, body) = Self.responses.isEmpty ? (200, "{}") : Self.responses.removeFirst()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@Suite(.serialized) struct AttestationRetryTests {
    private func functions(_ attestor: AppAttestor) -> EdgeFunctions {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return EdgeFunctions(supabaseURL: URL(string: "https://example.test")!, publishableKey: "key",
                             urlSession: URLSession(configuration: configuration), attestor: attestor) { "token" }
    }

    @Test func rejectedKeyIsReplacedAndTheRequestRetriedOnce() async throws {
        let service = FakeAttestService()
        let store = MemoryKeyStore()
        store.key = AttestKey(id: "vieja", isAttested: true)
        StubProtocol.requests = []
        StubProtocol.responses = [(403, #"{"error":"attestation_failed"}"#), (200, "{}")]
        try await functions(AppAttestor(service: service, store: store)).send("spark", body: ["mode": "extra"])
        #expect(StubProtocol.requests.count == 2)
        #expect(StubProtocol.requests[0].value(forHTTPHeaderField: AppAttestor.Header.keyID) == "vieja")
        #expect(StubProtocol.requests[1].value(forHTTPHeaderField: AppAttestor.Header.keyID) == "key-1")
        #expect(StubProtocol.requests[1].value(forHTTPHeaderField: AppAttestor.Header.attestation) != nil)
    }

    @Test func aSecondRejectionIsAnErrorButNotAccountRequired() async throws {
        StubProtocol.requests = []
        StubProtocol.responses = [(403, #"{"error":"attestation_failed"}"#), (403, #"{"error":"attestation_failed"}"#)]
        await #expect(throws: LumbreAPIError.unexpected) {
            try await functions(AppAttestor(service: FakeAttestService(), store: MemoryKeyStore())).send("spark", body: ["mode": "extra"])
        }
        #expect(StubProtocol.requests.count == 2)
    }

    @Test func plain403StillMeansAccountRequired() {
        #expect(EdgeFunctions.error(status: 403, body: Data(#"{"error":"account_required"}"#.utf8)) == .accountRequired)
    }
}

@Suite struct AIConsentTests {
    @Test func consentIsStoredInTheAccount() async throws {
        let api = MockLumbreAPI(latency: .zero)
        try await api.setAIConsent(false)
        #expect(await api.aiConsent == false)
    }
}

import Foundation
import Network
import os

/// Cola offline de capturas (plan.md §4). Si guardar falla por falta de red, la captura queda en disco
/// y se manda sola cuando vuelve la conexión o al abrir la app.
///
/// - Persiste en JSON en `LumbreShared.containerURL` (el App Group, así la Share Extension puede encolar también;
///   si no está disponible, Application Support). Los adjuntos (imagen, PDF) van como archivos aparte.
/// - Manda en orden. Un error de red frena el vaciado y reintenta con backoff; un error de validación descarta
///   esa captura y lo avisa en `updates()`.
/// - Varios procesos comparten el archivo (la app, la Share Extension y los App Intents): cada cambio relee el disco
///   y escribe con `NSFileCoordinator`, así una captura encolada desde otro proceso no se pisa.
/// - Nunca escribe en el log el contenido de las capturas.
public actor CaptureQueue {
    /// La cola de la app (y de la Share Extension).
    public static let shared = CaptureQueue(directory: defaultDirectory())

    /// Qué pasó con la cola, para que la interfaz se actualice.
    public enum Update: Sendable, Equatable {
        /// Cambió la cantidad de capturas pendientes.
        case count(Int)
        /// Se mandaron capturas encoladas.
        case flushed(sent: Int)
        /// Una captura no pasó la validación del servidor y se descartó.
        case discarded(LumbreAPIError)
    }

    /// Resultado de un vaciado.
    public struct FlushReport: Sendable, Equatable {
        public var sent: [CaptureResult] = []
        public var discarded: [LumbreAPIError] = []
        public var remaining: Int = 0
        /// Se frenó por falta de red o un error temporal: conviene reintentar más tarde.
        public var shouldRetry: Bool = false

        public init() {}
    }

    /// Una captura pendiente tal como queda en disco. Los adjuntos binarios van en `attachmentFile`.
    public struct PendingCapture: Codable, Sendable, Identifiable, Equatable {
        public let id: UUID
        public let createdAt: Date
        public let thesis: String?
        public let category: String
        public let sourceType: SourceType
        public let sourceURL: URL?
        public let sourceTitle: String?
        public let excerpt: String?
        public let localAssetID: String?
        public let distill: Bool
        /// Nombre del archivo del adjunto dentro de la carpeta de la cola.
        public let attachmentFile: String?
        /// Intentos fallidos por errores que no son de red.
        public var failures: Int
        /// Viene de importar notas (paso 89). Falta en las capturas encoladas antes del paso.
        public var importSource: ImportSource? = nil
    }

    private let directory: URL
    private let backoffBase: Duration
    private let maxBackoff: Duration
    private let maxFailures: Int
    private var items: [PendingCapture]
    private var isFlushing = false
    /// Manda una captura al backend. Es `LumbreAPI.capture` salvo en las pruebas.
    typealias Sender = @Sendable (CaptureRequest) async throws -> CaptureResult

    private var sender: Sender?
    private var monitor: NWPathMonitor?
    private var isOnline = true
    private var retryTask: Task<Void, Never>?
    private var retryAttempt = 0
    private var observers: [UUID: AsyncStream<Update>.Continuation] = [:]
    private let logger = Logger(subsystem: "com.matiasrodriguezc.lumbre", category: "capture-queue")

    /// - Parameters:
    ///   - directory: carpeta donde vive la cola (se crea si no existe).
    ///   - backoffBase: primera espera antes de reintentar; se duplica en cada intento.
    ///   - maxFailures: después de tantos errores que no son de red, la captura se descarta.
    public init(directory: URL, backoffBase: Duration = .seconds(2), maxBackoff: Duration = .seconds(300), maxFailures: Int = 5) {
        self.directory = directory
        self.backoffBase = backoffBase
        self.maxBackoff = maxBackoff
        self.maxFailures = maxFailures
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        items = Self.coordinatedRead(directory.appending(path: "queue.json"))
    }

    /// App Group si está disponible; si no, Application Support.
    public static func defaultDirectory() -> URL {
        LumbreShared.containerURL.appending(path: "CaptureQueue", directoryHint: .isDirectory)
    }

    // MARK: - Estado

    public var count: Int {
        reload()
        return items.count
    }

    public var pending: [PendingCapture] {
        reload()
        return items
    }

    /// Cambios de la cola. Arranca con la cantidad actual.
    public func updates() -> AsyncStream<Update> {
        reload()
        let id = UUID()
        let (stream, continuation) = AsyncStream<Update>.makeStream(bufferingPolicy: .bufferingNewest(16))
        observers[id] = continuation
        continuation.yield(.count(items.count))
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeObserver(id) }
        }
        return stream
    }

    private func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    private func notify(_ update: Update) {
        for continuation in observers.values {
            continuation.yield(update)
        }
    }

    // MARK: - Encolar

    /// Guarda la captura en disco para mandarla después.
    @discardableResult
    public func enqueue(_ request: CaptureRequest) throws -> PendingCapture {
        let id = UUID()
        var attachmentFile: String?
        var sourceURL: URL?
        switch request.source {
        case .image(let data):
            attachmentFile = "\(id.uuidString).jpg"
            try data.write(to: directory.appending(path: attachmentFile!), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        case .pdf(let data):
            attachmentFile = "\(id.uuidString).pdf"
            try data.write(to: directory.appending(path: attachmentFile!), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        case .link(let url):
            sourceURL = url
        case .selection(let url):
            sourceURL = url
        case .text, .voice, .screenshot, .scan:
            break
        }
        let item = PendingCapture(
            id: id, createdAt: .now, thesis: request.thesis, category: request.category,
            sourceType: request.source.sourceType, sourceURL: sourceURL, sourceTitle: request.sourceTitle,
            excerpt: request.excerpt, localAssetID: request.localAssetID, distill: request.distill,
            attachmentFile: attachmentFile, failures: 0, importSource: request.importSource
        )
        do {
            try mutate { $0.append(item) }
        } catch {
            if let attachmentFile { try? FileManager.default.removeItem(at: directory.appending(path: attachmentFile)) }
            throw error
        }
        logger.info("enqueued capture, \(self.items.count, privacy: .public) pending")
        notify(.count(items.count))
        return item
    }

    /// Encola varias capturas de texto de una vez, con una sola escritura (importar notas).
    /// Las que traen adjunto van de a una con `enqueue(_:)`.
    @discardableResult
    public func enqueue(contentsOf requests: [CaptureRequest]) throws -> [PendingCapture] {
        let items = requests.map { request -> PendingCapture in
            precondition(request.source.sourceType != .image && request.source.sourceType != .pdf, "enqueue(contentsOf:) es solo para texto")
            var sourceURL: URL?
            switch request.source {
            case .link(let url): sourceURL = url
            case .selection(let url): sourceURL = url
            default: break
            }
            return PendingCapture(
                id: UUID(), createdAt: .now, thesis: request.thesis, category: request.category,
                sourceType: request.source.sourceType, sourceURL: sourceURL, sourceTitle: request.sourceTitle,
                excerpt: request.excerpt, localAssetID: request.localAssetID, distill: request.distill,
                attachmentFile: nil, failures: 0, importSource: request.importSource
            )
        }
        guard !items.isEmpty else { return [] }
        try mutate { $0.append(contentsOf: items) }
        logger.info("enqueued \(items.count, privacy: .public) captures, \(self.items.count, privacy: .public) pending")
        notify(.count(self.items.count))
        return items
    }

    /// Saca una captura de la cola sin mandarla.
    public func remove(id: PendingCapture.ID) {
        reload()
        guard let item = items.first(where: { $0.id == id }) else { return }
        drop(item)
        notify(.count(items.count))
    }

    // MARK: - Vaciar

    /// Manda las capturas pendientes en orden. Frena en el primer error de red.
    @discardableResult
    public func flush(using api: any LumbreAPI) async -> FlushReport {
        await flush(send: { try await api.capture($0) })
    }

    @discardableResult
    func flush(send: Sender) async -> FlushReport {
        var report = FlushReport()
        guard !isFlushing else {
            report.remaining = items.count
            return report
        }
        isFlushing = true
        defer { isFlushing = false }
        // Otro proceso (la Share Extension, un atajo) pudo haber encolado algo.
        reload()

        while let item = items.first {
            let request: CaptureRequest
            do {
                request = try makeRequest(item)
            } catch {
                // El adjunto ya no está en disco: no hay forma de mandarla.
                drop(item)
                report.discarded.append(.invalidSource)
                notify(.discarded(.invalidSource))
                continue
            }
            do {
                let result = try await send(request)
                drop(item)
                report.sent.append(result)
            } catch {
                switch Self.classify(error) {
                case .connectivity, .retryLater:
                    report.shouldRetry = true
                case .rejected(let apiError):
                    drop(item)
                    report.discarded.append(apiError)
                    notify(.discarded(apiError))
                    logger.notice("discarded queued capture: \(apiError.analyticsCode, privacy: .public)")
                    continue
                case .transient:
                    let failures = try? mutate { items -> Int in
                        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return 0 }
                        items[index].failures += 1
                        return items[index].failures
                    }
                    if let failures, failures >= maxFailures {
                        drop(item)
                        report.discarded.append(.unexpected)
                        notify(.discarded(.unexpected))
                        continue
                    }
                    report.shouldRetry = true
                }
                break
            }
        }
        report.remaining = items.count
        if !report.sent.isEmpty {
            Analytics.track(.offlineQueueFlushed(count: report.sent.count))
            logger.info("flushed \(report.sent.count, privacy: .public) captures, \(report.remaining, privacy: .public) left")
            notify(.flushed(sent: report.sent.count))
        }
        if !report.sent.isEmpty || !report.discarded.isEmpty {
            notify(.count(items.count))
        }
        return report
    }

    // MARK: - Reintentos automáticos

    /// Vacía la cola ahora y cada vez que vuelve la red, con backoff si falla. Se puede llamar varias veces.
    public func startMonitoring(api: any LumbreAPI) {
        startMonitoring(send: { try await api.capture($0) })
    }

    func startMonitoring(send: @escaping Sender) {
        sender = send
        if monitor == nil {
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { [weak self] path in
                let online = path.status == .satisfied
                Task { await self?.pathChanged(online: online) }
            }
            monitor.start(queue: DispatchQueue(label: "com.matiasrodriguezc.lumbre.capture-queue.path"))
            self.monitor = monitor
        }
        scheduleFlush(after: .zero)
    }

    public func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
        retryTask?.cancel()
        retryTask = nil
    }

    private func pathChanged(online: Bool) {
        let cameBack = online && !isOnline
        isOnline = online
        if cameBack {
            retryAttempt = 0
            scheduleFlush(after: .zero)
        }
    }

    private func scheduleFlush(after delay: Duration) {
        reload()
        guard sender != nil, !items.isEmpty else { return }
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            await self?.runScheduledFlush()
        }
    }

    private func runScheduledFlush() async {
        guard let sender, isOnline else { return }
        let report = await flush(send: sender)
        if report.shouldRetry && report.remaining > 0 {
            retryAttempt += 1
            scheduleFlush(after: backoff(attempt: retryAttempt))
        } else {
            retryAttempt = 0
        }
    }

    /// base × 2^(intento − 1), con tope.
    nonisolated func backoff(attempt: Int) -> Duration {
        let factor = 1 << min(max(attempt - 1, 0), 16)
        return min(backoffBase * factor, maxBackoff)
    }

    // MARK: - Errores

    enum Failure: Equatable {
        /// Sin red: se queda en la cola.
        case connectivity
        /// Cupo del día agotado: se queda y se reintenta más tarde.
        case retryLater
        /// El servidor la rechazó por validación: se descarta.
        case rejected(LumbreAPIError)
        /// Error del servidor o desconocido: se reintenta unas veces.
        case transient
    }

    static func classify(_ error: Error) -> Failure {
        if isConnectivityError(error) { return .connectivity }
        if let apiError = error as? LumbreAPIError {
            switch apiError {
            case .offline: return .connectivity
            case .quotaExceeded: return .retryLater
            case .unexpected: return .transient
            default: return .rejected(apiError)
            }
        }
        return .transient
    }

    /// Errores de conectividad: la captura conviene encolarla en vez de mostrar un error.
    public static func isConnectivityError(_ error: Error) -> Bool {
        if let apiError = error as? LumbreAPIError { return apiError == .offline }
        let codes: Set<Int> = [
            URLError.notConnectedToInternet.rawValue, URLError.networkConnectionLost.rawValue,
            URLError.timedOut.rawValue, URLError.cannotFindHost.rawValue, URLError.cannotConnectToHost.rawValue,
            URLError.dnsLookupFailed.rawValue, URLError.internationalRoamingOff.rawValue,
            URLError.dataNotAllowed.rawValue, URLError.callIsActive.rawValue,
        ]
        var current: NSError? = error as NSError
        while let nsError = current {
            if nsError.domain == NSURLErrorDomain && codes.contains(nsError.code) { return true }
            current = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return false
    }

    // MARK: - Disco

    private func makeRequest(_ item: PendingCapture) throws -> CaptureRequest {
        let source: CaptureSource
        switch item.sourceType {
        case .text, .audio: source = .text
        case .voice: source = .voice
        case .selection: source = .selection(item.sourceURL)
        case .screenshot: source = .screenshot
        case .scan: source = .scan
        case .link:
            guard let url = item.sourceURL else { throw CocoaError(.fileReadCorruptFile) }
            source = .link(url)
        case .image: source = .image(try attachment(of: item))
        case .pdf: source = .pdf(try attachment(of: item))
        }
        return CaptureRequest(
            thesis: item.thesis, category: item.category, source: source, sourceTitle: item.sourceTitle,
            excerpt: item.excerpt, localAssetID: item.localAssetID, distill: item.distill,
            importSource: item.importSource
        )
    }

    private func attachment(of item: PendingCapture) throws -> Data {
        guard let file = item.attachmentFile else { throw CocoaError(.fileNoSuchFile) }
        return try Data(contentsOf: directory.appending(path: file))
    }

    private func drop(_ item: PendingCapture) {
        if (try? mutate({ $0.removeAll { $0.id == item.id } })) == nil {
            // No se pudo escribir: al menos que no se mande dos veces en este proceso.
            items.removeAll { $0.id == item.id }
        }
        deleteAttachment(of: item)
    }

    private func deleteAttachment(of item: PendingCapture) {
        if let file = item.attachmentFile {
            try? FileManager.default.removeItem(at: directory.appending(path: file))
        }
    }

    private var fileURL: URL { directory.appending(path: "queue.json") }

    /// Relee la cola del disco: otro proceso pudo haberla cambiado.
    private func reload() {
        items = Self.coordinatedRead(fileURL)
    }

    /// Lee lo último del disco, aplica el cambio y escribe, todo dentro de una escritura coordinada.
    @discardableResult
    private func mutate<T>(_ change: (inout [PendingCapture]) throws -> T) throws -> T {
        var outcome: Result<([PendingCapture], T), Error> = .failure(CocoaError(.fileWriteUnknown))
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: fileURL, options: .forMerging, error: &coordinationError) { url in
            var current = Self.read(url)
            outcome = Result {
                let value = try change(&current)
                let data = try Self.encoder.encode(current)
                try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                return (current, value)
            }
        }
        if let coordinationError { throw coordinationError }
        let (saved, value) = try outcome.get()
        items = saved
        return value
    }

    private static func coordinatedRead(_ file: URL) -> [PendingCapture] {
        var result: [PendingCapture] = []
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &coordinationError) { url in
            result = read(url)
        }
        return result
    }

    private static func read(_ url: URL) -> [PendingCapture] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([PendingCapture].self, from: data)) ?? []
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension LumbreAPIError {
    /// Código corto para logs y eventos (nunca contenido del usuario).
    public var analyticsCode: String {
        switch self {
        case .quotaExceeded: "quota_exceeded"
        case .tooManyCategories: "too_many_categories"
        case .invalidThesis: "invalid_thesis"
        case .invalidCategory: "invalid_category"
        case .invalidSource: "invalid_source"
        case .needsThesis: "needs_thesis"
        case .proRequired: "pro_required"
        case .notEnoughConcepts: "not_enough_concepts"
        case .tooManyProjects: "too_many_projects"
        case .accountRequired: "account_required"
        case .invalidEmail: "invalid_email"
        case .invalidCode: "invalid_code"
        case .emailInUse: "email_in_use"
        case .importLimitReached: "import_limit"
        case .offline: "offline"
        case .unexpected: "unexpected"
        }
    }
}

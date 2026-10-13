import Foundation

/// Cliente de las Edge Functions (`backend/openapi.yaml`): POST con JSON, el access token del usuario y la clave publicable.
/// Va sobre URLSession y no sobre `client.functions` para leer el código de error también en el stream del planificador.
struct EdgeFunctions: Sendable {
    let baseURL: URL
    let publishableKey: String
    let urlSession: URLSession
    /// Access token vigente de la sesión (Auth lo renueva si venció).
    let accessToken: @Sendable () async throws -> String

    init(supabaseURL: URL, publishableKey: String, urlSession: URLSession = .shared, accessToken: @escaping @Sendable () async throws -> String) {
        baseURL = supabaseURL.appending(path: "functions/v1")
        self.publishableKey = publishableKey
        self.urlSession = urlSession
        self.accessToken = accessToken
    }

    /// Llama a la función y decodifica la respuesta.
    func call<Response: Decodable>(_ name: String, body: some Encodable, timeout: TimeInterval = 60) async throws -> Response {
        let data = try await callRaw(name, body: body, timeout: timeout)
        return try LumbreJSON.decoder().decode(Response.self, from: data)
    }

    /// Llama a la función y descarta la respuesta.
    func send(_ name: String, body: some Encodable) async throws {
        _ = try await callRaw(name, body: body, timeout: 30)
    }

    func callRaw(_ name: String, body: some Encodable, timeout: TimeInterval) async throws -> Data {
        let request = try await makeRequest(name, body: body, timeout: timeout, accept: "application/json")
        let (data, response) = try await urlSession.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw Self.error(status: status, body: data)
        }
        return data
    }

    /// Llama a una función que responde `text/event-stream` y entrega cada evento a `onEvent`.
    /// Termina cuando el servidor cierra el stream, cuando `onEvent` devuelve false o cuando se cancela la tarea.
    func events(_ name: String, body: some Encodable, onEvent: (SSEEvent) throws -> Bool) async throws {
        let request = try await makeRequest(name, body: body, timeout: 120, accept: "text/event-stream")
        let (bytes, response) = try await urlSession.bytes(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            var data = Data()
            for try await byte in bytes { data.append(byte) }
            throw Self.error(status: status, body: data)
        }

        var parser = SSEParser()
        var line = Data()
        for try await byte in bytes {
            line.append(byte)
            // Se le pasa al parser de a una línea: así no se corta un carácter UTF-8 por la mitad.
            guard byte == UInt8(ascii: "\n") else { continue }
            for event in parser.feed(line) {
                guard try onEvent(event) else { return }
            }
            line.removeAll(keepingCapacity: true)
        }
        for event in parser.feed(line) + parser.finish() {
            guard try onEvent(event) else { return }
        }
    }

    private func makeRequest(_ name: String, body: some Encodable, timeout: TimeInterval, accept: String) async throws -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: name), timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accept, forHTTPHeaderField: "Accept")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = try LumbreJSON.encoder().encode(body)
        return request
    }

    /// Traduce `{ "error": "<código>" }`. Si el cuerpo no trae un código conocido, se guía por el estado HTTP.
    static func error(status: Int, body: Data) -> LumbreAPIError {
        if let code = try? JSONDecoder().decode(ErrorDTO.self, from: body).error,
           let error = LumbreAPIError(serverMessage: code) {
            return error
        }
        return switch status {
        case 402: .proRequired
        case 403: .accountRequired
        case 422: .needsThesis
        case 429: .quotaExceeded
        default: .unexpected
        }
    }
}

/// Cuerpo vacío (`{}`) para las funciones que no piden nada.
struct EmptyBody: Encodable, Sendable {}

// MARK: - Server-Sent Events

struct SSEEvent: Equatable, Sendable {
    var event: String
    var data: String
}

/// Parser incremental de `text/event-stream`: recibe los bytes en pedazos de cualquier tamaño y devuelve
/// los eventos completos. Sigue la especificación en lo que usa el backend: `event:`, `data:` (varias líneas
/// se unen con `\n`), comentarios con `:` y líneas terminadas en `\n`, `\r\n` o `\r`.
struct SSEParser: Sendable {
    private var buffer = Data()
    private var eventName = ""
    private var dataLines: [String] = []
    private var sawData = false

    mutating func feed(_ chunk: Data) -> [SSEEvent] {
        buffer.append(chunk)
        var events: [SSEEvent] = []
        while let end = buffer.firstIndex(where: { $0 == 10 || $0 == 13 }) {
            // Un \r al final del pedazo puede ser la mitad de un \r\n: se espera al próximo.
            if buffer[end] == 13, end == buffer.index(before: buffer.endIndex) { break }
            let lineData = buffer[buffer.startIndex..<end]
            var next = buffer.index(after: end)
            if buffer[end] == 13, next < buffer.endIndex, buffer[next] == 10 { next = buffer.index(after: next) }
            let line = String(decoding: lineData, as: UTF8.self)
            buffer = Data(buffer[next...])
            if let event = process(line) { events.append(event) }
        }
        return events
    }

    /// Cierra el stream. Si quedó un evento sin la línea vacía final, se entrega igual
    /// (la especificación lo descarta, pero así no se pierde un `done` o un `error` si el servidor corta antes).
    mutating func finish() -> [SSEEvent] {
        var events: [SSEEvent] = []
        if !buffer.isEmpty, let event = process(String(decoding: buffer, as: UTF8.self)) { events.append(event) }
        buffer.removeAll()
        if let event = process("") { events.append(event) }
        return events
    }

    private mutating func process(_ line: String) -> SSEEvent? {
        if line.isEmpty {
            defer {
                eventName = ""
                dataLines = []
                sawData = false
            }
            guard sawData else { return nil }
            return SSEEvent(event: eventName.isEmpty ? "message" : eventName, data: dataLines.joined(separator: "\n"))
        }
        if line.hasPrefix(":") { return nil }
        let field: Substring
        var value: Substring
        if let colon = line.firstIndex(of: ":") {
            field = line[..<colon]
            value = line[line.index(after: colon)...]
            if value.hasPrefix(" ") { value = value.dropFirst() }
        } else {
            field = Substring(line)
            value = ""
        }
        switch field {
        case "event": eventName = String(value)
        case "data":
            dataLines.append(String(value))
            sawData = true
        default: break
        }
        return nil
    }
}

/// Lo que significa cada evento del planificador (`delta`, `done`, `error`).
enum PlannerEvent: Equatable, Sendable {
    case text(String)
    case done(messageID: Int?)
    case ignored

    private struct Delta: Decodable { let text: String }
    private struct Done: Decodable { let messageId: Int? }

    init(_ event: SSEEvent) throws {
        let data = Data(event.data.utf8)
        let decoder = LumbreJSON.decoder()
        switch event.event {
        case "delta":
            self = .text(try decoder.decode(Delta.self, from: data).text)
        case "done":
            self = .done(messageID: (try? decoder.decode(Done.self, from: data))?.messageId)
        case "error":
            let code = (try? decoder.decode(ErrorDTO.self, from: data))?.error ?? ""
            throw LumbreAPIError(serverMessage: code) ?? .unexpected
        default:
            self = .ignored
        }
    }
}

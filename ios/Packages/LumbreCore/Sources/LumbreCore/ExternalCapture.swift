import Foundation

/// Guarda una captura desde fuera de la app (Share Extension, App Intents).
///
/// Si la app dejó un backend y una sesión vigente en el App Group, la manda directo con esa sesión prestada
/// (sin renovarla). Si no hay sesión, no hay red o el servidor falla, queda en la cola offline compartida y la manda
/// la app la próxima vez que se abre. Solo un rechazo de validación vuelve como error, para mostrarlo.
public enum ExternalCapture {
    public enum Outcome: Sendable, Equatable {
        /// Llegó al servidor.
        case sent
        /// Quedó en la cola: la manda la app.
        case queued
        /// El servidor la rechazó (texto vacío, categoría inválida…): no se encola.
        case rejected(LumbreAPIError)
    }

    public typealias Sender = @Sendable (CaptureRequest) async throws -> CaptureResult

    /// Manda o encola con lo que dejó la app en el App Group.
    public static func submit(_ request: CaptureRequest, queue: CaptureQueue = .shared) async throws -> Outcome {
        var send: Sender?
        if let backend = LumbreShared.backend {
            let api = SupabaseLumbreAPI.borrowingSharedSession(url: backend.url, publishableKey: backend.publishableKey)
            send = { try await api.capture($0) }
        }
        return try await submit(request, queue: queue, send: send)
    }

    /// - Parameter send: nil sin backend (los datos de prueba): se encola directo.
    public static func submit(_ request: CaptureRequest, queue: CaptureQueue, send: Sender?) async throws -> Outcome {
        guard let send else {
            try await queue.enqueue(request)
            return .queued
        }
        do {
            _ = try await send(request)
            return .sent
        } catch {
            switch CaptureQueue.classify(error) {
            case .rejected(let apiError):
                return .rejected(apiError)
            case .connectivity, .retryLater, .transient:
                try await queue.enqueue(request)
                return .queued
            }
        }
    }
}

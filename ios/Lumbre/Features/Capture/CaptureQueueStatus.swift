import LumbreCore
import LumbreDesign
import SwiftUI

/// Sigue la cola offline: cuántas capturas esperan, recarga las pantallas cuando se mandan y avisa si se descartó alguna.
/// La Bóveda lo usa; también se puede poner en `RootView` para que la cola arranque al abrir la app.
struct CaptureQueueMonitor: ViewModifier {
    @Binding var pendingCount: Int
    /// Se acabó el cupo de capturas de hoy: lo que queda sigue mañana.
    var isWaitingForQuota: Binding<Bool> = .constant(false)
    @Environment(\.api) private var api
    @Environment(AppModel.self) private var appModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var discardedMessage: String?

    func body(content: Content) -> some View {
        content
            .task {
                guard FeatureFlag.offlineQueue.isEnabled else { return }
                await CaptureQueue.shared.startMonitoring(api: api)
                for await update in await CaptureQueue.shared.updates() {
                    switch update {
                    case .count(let count):
                        pendingCount = count
                    case .flushed:
                        appModel.dataChanged()
                    case .discarded(let error):
                        discardedMessage = Self.message(for: error)
                    case .waitingForQuota(let waiting):
                        isWaitingForQuota.wrappedValue = waiting
                    }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, FeatureFlag.offlineQueue.isEnabled else { return }
                Task { await CaptureQueue.shared.startMonitoring(api: api) }
            }
            .alert("No pudimos guardar una captura", isPresented: Binding(get: { discardedMessage != nil }, set: { if !$0 { discardedMessage = nil } })) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(discardedMessage ?? "")
            }
    }

    private static func message(for error: LumbreAPIError) -> String {
        let reason = error.errorDescription ?? String(localized: "Algo salió mal.")
        return String(localized: "Una captura que guardaste sin conexión no se pudo mandar y la sacamos de la cola. \(reason)")
    }
}

extension View {
    /// Vacía la cola offline cuando vuelve la red o la app pasa a primer plano, y expone cuántas capturas esperan.
    func captureQueueMonitoring(pendingCount: Binding<Int> = .constant(0), isWaitingForQuota: Binding<Bool> = .constant(false)) -> some View {
        modifier(CaptureQueueMonitor(pendingCount: pendingCount, isWaitingForQuota: isWaitingForQuota))
    }
}

/// Indicador chico de capturas que esperan conexión. Tocarlo reintenta.
struct PendingCapturesBanner: View {
    let count: Int
    /// Esperan porque se acabó el cupo de hoy (por ejemplo, después de importar notas), no por falta de red.
    var isWaitingForQuota = false
    @Environment(\.api) private var api
    @State private var isRetrying = false

    var body: some View {
        Button {
            isRetrying = true
            Task {
                await CaptureQueue.shared.flush(using: api)
                isRetrying = false
            }
        } label: {
            HStack(spacing: Space.s2) {
                if isRetrying {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "icloud.and.arrow.up")
                        .foregroundStyle(Palette.infoText)
                }
                Group {
                    if isWaitingForQuota {
                        Text(count == 1 ? "1 captura sigue mañana: llegaste al tope de hoy" : "\(count) capturas siguen mañana: llegaste al tope de hoy")
                    } else {
                        Text(count == 1 ? "1 captura espera conexión" : "\(count) capturas esperan conexión")
                    }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                Text("Reintentar")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.infoText)
            }
            .padding(.horizontal, Space.s3)
            .frame(minHeight: 44)
            .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isRetrying)
        .accessibilityHint(Text("Intenta mandarlas ahora"))
    }
}

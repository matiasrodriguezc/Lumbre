import LumbreDesign
import SwiftUI

/// Error de carga con reintento. El diseño definitivo de los estados de error llega con el paso 11.
struct LoadErrorView: View {
    let error: Error
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("No pudimos conectarnos", systemImage: "wifi.exclamationmark")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Reintentar", action: retry)
                .buttonStyle(.lumbre(.secondary))
        }
        .padding(.top, Space.s8)
    }
}

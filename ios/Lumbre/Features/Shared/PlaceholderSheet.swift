import LumbreDesign
import SwiftUI

/// Sheet provisoria para las pantallas que todavía no existen.
struct PlaceholderSheet: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: "hammer", description: Text(message))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.surface)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Listo") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium])
    }
}

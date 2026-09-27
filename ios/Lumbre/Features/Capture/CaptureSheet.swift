import LumbreCore
import LumbreDesign
import SwiftUI

struct CaptureSheet: View {
    enum Kind: String, CaseIterable, Identifiable {
        case text, link, voice, photo
        var id: String { rawValue }

        var label: LocalizedStringKey {
            switch self {
            case .text: return "Texto"
            case .link: return "Link"
            case .voice: return "Voz"
            case .photo: return "Foto"
            }
        }
    }

    @Environment(\.api) private var api
    @Environment(\.dismiss) private var dismiss
    @State private var kind: Kind = .text
    @State private var text = ""
    @State private var distill = true
    @State private var isSaving = false
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.s5) {
                Picker("Tipo", selection: $kind) {
                    ForEach(Kind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                input

                if kind != .text {
                    Toggle(isOn: $distill) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Destilar automáticamente")
                                .font(.headline)
                            Text("Lumbre lee el contenido y saca los conceptos.")
                                .font(.footnote)
                                .foregroundStyle(Palette.inkMuted)
                            Text("Te quedan 3 pruebas este mes · Ilimitado en Pro")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Palette.proText)
                        }
                    }
                }

                Spacer(minLength: 0)

                Button {
                    save()
                } label: {
                    if isSaving {
                        ProgressView().tint(Palette.onAccent)
                    } else {
                        Text("Guardar concepto")
                    }
                }
                .buttonStyle(.lumbre(.primary, fullWidth: true))
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
            }
            .padding(Space.s4)
            .foregroundStyle(Palette.ink)
            .background(Palette.surface)
            .navigationTitle("Nuevo concepto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(Radius.lg)
        .onAppear { isEditorFocused = true }
    }

    @ViewBuilder
    private var input: some View {
        switch kind {
        case .text:
            field("¿Qué idea te quedó dando vueltas?", axis: .vertical)
        case .link:
            field("https://", axis: .horizontal)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
        case .voice:
            Label("Tocá para grabar. La voz se transcribe en el teléfono.", systemImage: "mic")
                .font(.callout)
                .foregroundStyle(Palette.inkMuted)
                .frame(maxWidth: .infinity, minHeight: 96)
                .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        case .photo:
            Label("Elegí una foto o una captura. El texto se lee en el teléfono.", systemImage: "photo")
                .font(.callout)
                .foregroundStyle(Palette.inkMuted)
                .frame(maxWidth: .infinity, minHeight: 96)
                .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        }
    }

    private func field(_ prompt: LocalizedStringKey, axis: Axis) -> some View {
        TextField(prompt, text: $text, axis: axis)
            .lineLimit(axis == .vertical ? 4...8 : 1...1)
            .focused($isEditorFocused)
            .padding(Space.s3)
            .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).strokeBorder(Palette.borderStrong, lineWidth: 1))
    }

    private func save() {
        isSaving = true
        Task {
            _ = try? await api.capture(text: text, distill: distill && kind != .text)
            dismiss()
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        CaptureSheet()
    }
    .preferredColorScheme(.dark)
}

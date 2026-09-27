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

        /// Por ahora se guardan textos y links; voz y foto llegan con los pasos 48 y 50.
        var isAvailable: Bool { self == .text || self == .link }
    }

    private enum Field { case thesis, link, category }

    /// Se llama después de guardar, para que las pantallas vuelvan a cargar.
    var onSaved: () -> Void = {}

    @Environment(\.api) private var api
    @Environment(\.dismiss) private var dismiss
    @State private var kind: Kind = .text
    @State private var thesis = ""
    @State private var link = ""
    @State private var categoryName = ""
    @State private var categories: [LumbreCore.Category] = []
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var focus: Field?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s5) {
                    Picker("Tipo", selection: $kind) {
                        ForEach(Kind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    input

                    if kind.isAvailable {
                        categorySection
                    }
                }
                .padding(Space.s4)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                saveButton
                    .padding(.horizontal, Space.s4)
                    .padding(.bottom, Space.s2)
            }
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
        .presentationDetents([.large])
        .presentationCornerRadius(Radius.lg)
        .task { categories = (try? await api.categories()) ?? [] }
        .onAppear { focus = .thesis }
        .alert("No se pudo guardar", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Contenido

    @ViewBuilder
    private var input: some View {
        switch kind {
        case .text:
            field("¿Qué idea te quedó dando vueltas?", text: $thesis, field: .thesis, axis: .vertical)
        case .link:
            field("https://", text: $link, field: .link, axis: .horizontal)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            field("¿Qué idea te deja esto?", text: $thesis, field: .thesis, axis: .vertical)
        case .voice:
            comingSoon("Grabar una nota de voz llega pronto. Mientras tanto, dictá con el micrófono del teclado.", systemImage: "mic")
        case .photo:
            comingSoon("Guardar fotos y capturas llega pronto.", systemImage: "photo")
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("Categoría")
                .font(.headline)
            if !categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s2) {
                        ForEach(categories) { category in
                            Button {
                                categoryName = category.name
                            } label: {
                                LumbreChip(category.name, systemImage: category.symbol, variant: matches(category) ? .on : .select)
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollClipDisabled()
            }
            field(categories.isEmpty ? "Por ejemplo: Marketing" : "O escribí una nueva", text: $categoryName, field: .category, axis: .horizontal)
                .submitLabel(.done)
            if isNewCategory {
                Label("Se crea la categoría “\(trimmedCategory)”", systemImage: "plus.circle")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.inkMuted)
            } else if categories.isEmpty {
                Text("Todavía no tenés categorías: se crean a medida que guardás conceptos.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
            }
        }
    }

    private var saveButton: some View {
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
        .disabled(!canSave || isSaving)
    }

    private func field(_ prompt: LocalizedStringKey, text: Binding<String>, field: Field, axis: Axis) -> some View {
        TextField(prompt, text: text, axis: axis)
            .lineLimit(axis == .vertical ? 4...8 : 1...1)
            .focused($focus, equals: field)
            .padding(Space.s3)
            .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).strokeBorder(Palette.borderStrong, lineWidth: 1))
    }

    private func comingSoon(_ message: LocalizedStringKey, systemImage: String) -> some View {
        Label(message, systemImage: systemImage)
            .font(.callout)
            .foregroundStyle(Palette.inkMuted)
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(.horizontal, Space.s3)
            .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }

    // MARK: - Lógica

    private var trimmedCategory: String {
        categoryName.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Misma comparación que el servidor: sin acentos, sin mayúsculas y con los espacios colapsados.
    private static func normalized(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private func matches(_ category: LumbreCore.Category) -> Bool {
        !trimmedCategory.isEmpty && Self.normalized(category.name) == Self.normalized(trimmedCategory)
    }

    private var isNewCategory: Bool {
        !trimmedCategory.isEmpty && !categories.contains(where: matches)
    }

    private var linkURL: URL? {
        guard let url = URL(string: link.trimmingCharacters(in: .whitespaces)), url.scheme?.hasPrefix("http") == true, url.host != nil else {
            return nil
        }
        return url
    }

    private var canSave: Bool {
        guard kind.isAvailable else { return false }
        let hasThesis = !thesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasThesis && !trimmedCategory.isEmpty && (kind != .link || linkURL != nil)
    }

    private func save() {
        let source: CaptureSource = kind == .link ? linkURL.map(CaptureSource.link) ?? .text : .text
        isSaving = true
        Task {
            do {
                _ = try await api.capture(thesis: thesis, category: trimmedCategory, source: source)
                onSaved()
                dismiss()
            } catch {
                saveError = error.localizedDescription
                isSaving = false
            }
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        CaptureSheet()
    }
    .preferredColorScheme(.dark)
}

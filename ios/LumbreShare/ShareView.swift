import LumbreCore
import LumbreDesign
import SwiftUI

/// UI compacta de la Share Extension: lo que llegó, "¿Qué idea te deja esto?" y la categoría.
struct ShareView: View {
    @Bindable var model: ShareModel
    let onCancel: () -> Void
    let onDone: () -> Void

    @FocusState private var focus: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Field { case thesis, category }

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Palette.bg)
                .navigationTitle(Text("Guardar en Lumbre"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar", action: onCancel)
                    }
                    if model.phase == .editing || model.phase == .saving {
                        ToolbarItem(placement: .confirmationAction) {
                            Button {
                                Task { await save() }
                            } label: {
                                if model.phase == .saving {
                                    ProgressView()
                                } else {
                                    Text("Guardar").fontWeight(.semibold)
                                }
                            }
                            .disabled(!model.canSave)
                        }
                    }
                }
        }
        .tint(Palette.ink)
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView()
                .padding(.top, Space.s10)
        case .unavailable(let message):
            statusMessage(message, systemImage: "exclamationmark.circle")
        case .done(let message):
            statusMessage(message, systemImage: "checkmark.circle.fill")
                .transition(.opacity)
        case .editing, .saving:
            form
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s5) {
                SourcePreview(draft: model.draft, preview: model.preview)
                thesisField
                categoryField
                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Palette.danger)
                }
            }
            .padding(Space.s4)
        }
        .scrollDismissesKeyboard(.interactively)
        .disabled(model.phase == .saving)
        .onAppear { focus = model.thesis.isEmpty ? .thesis : (model.trimmedCategory.isEmpty ? .category : nil) }
    }

    private var thesisField: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(model.draft.kind == .text ? LocalizedStringKey("Tu idea") : LocalizedStringKey("¿Qué idea te deja esto?"))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            TextField("Escribila en una frase", text: $model.thesis, axis: .vertical)
                .lineLimit(2...6)
                .focused($focus, equals: .thesis)
                .padding(Space.s3)
                .frame(minHeight: 44)
                .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).strokeBorder(Palette.borderStrong, lineWidth: 1))
                .accessibilityLabel(Text("Idea"))
            if model.isThesisTooLong {
                Label("Dejala en \(SharedDraft.thesisLimit) caracteres o menos", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.warning)
            }
        }
    }

    private var categoryField: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("Categoría")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if !model.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s2) {
                        ForEach(model.categories, id: \.self) { name in
                            CategoryChip(name: name, isOn: model.isSelected(name)) {
                                model.category = name
                            }
                        }
                    }
                }
                .scrollClipDisabled()
            }
            TextField(model.categories.isEmpty ? LocalizedStringKey("Por ejemplo: Marketing") : LocalizedStringKey("O escribí una nueva"), text: $model.category)
                .focused($focus, equals: .category)
                .submitLabel(.done)
                .textInputAutocapitalization(.sentences)
                .padding(Space.s3)
                .frame(minHeight: 44)
                .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).strokeBorder(Palette.borderStrong, lineWidth: 1))
                .accessibilityLabel(Text("Categoría"))
            if model.createsCategory {
                Label("Se crea la categoría “\(model.trimmedCategory)”", systemImage: "plus.circle")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.inkMuted)
            }
        }
    }

    private func statusMessage(_ text: String, systemImage: String) -> some View {
        VStack(spacing: Space.s3) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(Palette.ink)
                .accessibilityHidden(true)
            Text(text)
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
        }
        .padding(Space.s6)
        .padding(.top, Space.s8)
        .accessibilityElement(children: .combine)
    }

    private func save() async {
        focus = nil
        guard await model.save() else { return }
        if case .done(let message) = model.phase {
            AccessibilityNotification.Announcement(message).post()
        }
        try? await Task.sleep(for: .milliseconds(1100))
        onDone()
    }
}

/// Lo que llegó: miniatura, PDF, link o el fragmento seleccionado, sobre `surface-alt`.
private struct SourcePreview: View {
    let draft: SharedDraft
    let preview: UIImage?

    var body: some View {
        HStack(alignment: .top, spacing: Space.s3) {
            if let preview {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    .accessibilityHidden(true)
            } else {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(Palette.inkMuted)
                    .frame(width: 28)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: Space.s1) {
                Text(kindLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.inkMuted)
                if let label = draft.sourceLabel {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                }
                if let excerpt = draft.excerpt {
                    Text("“\(excerpt)”")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Space.s3)
        .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch draft.kind {
        case .pdf: "doc.richtext"
        case .image: "photo"
        case .link: "link"
        case .selection: "text.quote"
        case .text: "text.alignleft"
        }
    }

    private var kindLabel: LocalizedStringKey {
        switch draft.kind {
        case .pdf: "PDF"
        case .image: "Imagen"
        case .link: "Link"
        case .selection: "Texto seleccionado"
        case .text: "Texto"
        }
    }
}

/// Chip de categoría: elegida en `accent` con `on-accent`; las otras con contorno `border-strong`.
private struct CategoryChip: View {
    let name: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isOn ? Palette.onAccent : Palette.ink)
                .padding(.horizontal, Space.s3)
                .frame(minHeight: 36)
                .background(isOn ? Palette.accent : Color.clear, in: Capsule())
                .overlay(Capsule().strokeBorder(isOn ? Color.clear : Palette.borderStrong, lineWidth: 1))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

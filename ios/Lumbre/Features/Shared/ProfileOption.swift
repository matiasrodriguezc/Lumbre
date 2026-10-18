import LumbreCore
import LumbreDesign
import SwiftUI

/// Componente ProfileOption (`design/system/components/ProfileOption`): opción seleccionable de perfil creativo.
/// Seleccionado: fondo `accent-soft`, borde de 2px `accent` e ícono sobre `accent`. Es un toggle para VoiceOver.
struct ProfileOption: View {
    let systemImage: String
    let title: LocalizedStringKey
    let detail: Text
    let isSelected: Bool
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// El recuadro crece con el ícono: fijo en 36, con texto grande el ícono se salía y pisaba el título.
    @ScaledMetric(relativeTo: .body) private var iconBox: CGFloat = 36

    var body: some View {
        // Con tamaños de accesibilidad, el ícono va arriba: al lado, "oportunidades" se cortaba por sílabas.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.s2))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Space.s3))
        Button(action: action) {
            layout {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? Palette.onAccent : Palette.ink)
                    .frame(width: iconBox, height: iconBox)
                    .background(isSelected ? Palette.accent : Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                    detail
                        .font(.callout)
                        .foregroundStyle(Palette.inkMuted)
                        // El rol propio puede tener 200 caracteres: en la opción alcanza con el principio.
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
            }
            .padding(Space.s4)
            .background(isSelected ? Palette.surfaceAlt : Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(isSelected ? Palette.accent : Palette.border, lineWidth: isSelected ? 2 : 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .opacity(isEnabled || isSelected ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isToggle] : .isToggle)
        .accessibilityHint(isEnabled || isSelected ? Text("") : Text("Ya elegiste dos. Sacá uno para elegir este."))
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

/// Selector de hasta dos perfiles creativos, con ProfileOption. El último, "Personalizado", lleva a una pantalla para
/// escribir el rol con palabras propias y cuenta como uno de los dos.
struct CreativeProfilePicker: View {
    @Binding var selection: [CreativeProfile]
    @Binding var role: String
    static let maxSelection = 2
    @State private var isEditingRole = false

    private var hasRole: Bool { !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var chosen: Int { selection.count + (hasRole ? 1 : 0) }

    var body: some View {
        VStack(spacing: Space.s3) {
            ForEach(CreativeProfile.allCases) { profile in
                let isSelected = selection.contains(profile)
                ProfileOption(
                    systemImage: profile.symbol,
                    title: profile.title,
                    detail: Text(profile.detail),
                    isSelected: isSelected,
                    isEnabled: chosen < Self.maxSelection
                ) {
                    toggle(profile)
                }
            }
            ProfileOption(
                systemImage: "person.text.rectangle",
                title: "Personalizado",
                detail: hasRole ? Text(verbatim: role.trimmingCharacters(in: .whitespacesAndNewlines)) : Text("Contá tu rol con tus palabras"),
                isSelected: hasRole,
                isEnabled: chosen < Self.maxSelection
            ) {
                if hasRole || chosen < Self.maxSelection { isEditingRole = true }
            }
        }
        .navigationDestination(isPresented: $isEditingRole) {
            CreativeRoleEditor(role: $role)
        }
    }

    private func toggle(_ profile: CreativeProfile) {
        if let index = selection.firstIndex(of: profile) {
            selection.remove(at: index)
        } else if chosen < Self.maxSelection {
            selection.append(profile)
        }
    }
}

/// Pantalla para escribir el rol: un campo alto, con un ejemplo largo, y el botón arriba del teclado.
/// Solo se usa como contexto para las chispas y el planificador.
struct CreativeRoleEditor: View {
    @Binding var role: String
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var isFocused: Bool
    static let maxLength = 200

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s4) {
                Text("Tu rol")
                    .lumbreDisplay(.title1)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Contá a qué te dedicás o qué querés crear. Lo usamos solo para que las chispas y el planificador te hablen a vos.")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                ZStack(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text("Ej.: Soy diseñadora de producto en una fintech y me interesan los servicios para gente que nunca tuvo una cuenta bancaria.")
                            .font(.body)
                            .foregroundStyle(Palette.inkMuted)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    TextEditor(text: Binding(get: { draft }, set: { draft = String($0.prefix(Self.maxLength)) }))
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .focused($isFocused)
                        .accessibilityLabel(Text("Tu rol"))
                }
                .frame(minHeight: 160, alignment: .topLeading)
                .padding(Space.s3)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(isFocused ? Palette.focusRing : Palette.borderStrong, lineWidth: isFocused ? 2 : 1))
                Text("\(draft.count) de \(Self.maxLength)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Palette.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(Space.s4)
        }
        .scrollDismissesKeyboard(.interactively)
        // El botón va pegado abajo y sube con el teclado: el campo queda siempre a la vista.
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Space.s2) {
                Button("Listo") {
                    role = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    dismiss()
                }
                .buttonStyle(.lumbre(.primary, fullWidth: true))
                if !role.isEmpty {
                    Button("Quitar mi rol") {
                        role = ""
                        dismiss()
                    }
                    .buttonStyle(.lumbre(.ghost, fullWidth: true))
                }
            }
            .padding(.horizontal, Space.s4)
            .padding(.vertical, Space.s2)
            .background(Palette.bg)
        }
        .neuralBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            draft = role
            isFocused = true
        }
    }
}

extension CreativeProfile {
    var symbol: String {
        switch self {
        case .software: "chevron.left.forwardslash.chevron.right"
        case .content: "pencil.line"
        case .business: "briefcase"
        case .design: "paintpalette"
        case .curiosity: "binoculars"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .software: "Software y apps"
        case .content: "Contenido y escritura"
        case .business: "Negocios"
        case .design: "Diseño"
        case .curiosity: "Curiosidad libre"
        }
    }

    var titleString: String {
        switch self {
        case .software: String(localized: "Software y apps")
        case .content: String(localized: "Contenido y escritura")
        case .business: String(localized: "Negocios")
        case .design: String(localized: "Diseño")
        case .curiosity: String(localized: "Curiosidad libre")
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .software: "Productos, features y arquitectura"
        case .content: "Guiones, hilos, ensayos y ficción"
        case .business: "Modelos, servicios y oportunidades"
        case .design: "Interfaces, marca y producto físico"
        case .curiosity: "Ideas por el gusto de pensarlas"
        }
    }

    /// Categorías que se sugieren para las ideas semilla de este perfil.
    var suggestedCategories: [String] {
        switch self {
        case .software: [String(localized: "Software"), String(localized: "Producto")]
        case .content: [String(localized: "Escritura"), String(localized: "Narrativa")]
        case .business: [String(localized: "Negocios"), String(localized: "Marketing")]
        case .design: [String(localized: "Diseño"), String(localized: "Interfaces")]
        case .curiosity: [String(localized: "Ciencia"), String(localized: "Historia")]
        }
    }
}

extension [CreativeProfile] {
    /// "Software y apps y Negocios", o "Sin elegir".
    var summary: String {
        isEmpty ? String(localized: "Sin elegir") : map(\.titleString).formatted(.list(type: .and))
    }
}

#Preview {
    @Previewable @State var selection: [CreativeProfile] = [.software]
    @Previewable @State var role = ""
    NavigationStack {
        ScrollView {
            CreativeProfilePicker(selection: $selection, role: $role)
                .padding()
        }
        .background(Palette.bg)
    }
    .preferredColorScheme(.light)
}

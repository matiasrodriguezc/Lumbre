import LumbreCore
import LumbreDesign
import SwiftUI

/// Componente ProfileOption (`design/system/components/ProfileOption`): opción seleccionable de perfil creativo.
/// Seleccionado: fondo `accent-soft`, borde de 2px `accent` e ícono sobre `accent`. Es un toggle para VoiceOver.
struct ProfileOption: View {
    let systemImage: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
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
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(Palette.inkMuted)
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

/// Selector de hasta dos perfiles creativos, con ProfileOption.
struct CreativeProfilePicker: View {
    @Binding var selection: [CreativeProfile]
    static let maxSelection = 2

    var body: some View {
        VStack(spacing: Space.s3) {
            ForEach(CreativeProfile.allCases) { profile in
                let isSelected = selection.contains(profile)
                ProfileOption(
                    systemImage: profile.symbol,
                    title: profile.title,
                    detail: profile.detail,
                    isSelected: isSelected,
                    isEnabled: selection.count < Self.maxSelection
                ) {
                    toggle(profile)
                }
            }
        }
    }

    private func toggle(_ profile: CreativeProfile) {
        if let index = selection.firstIndex(of: profile) {
            selection.remove(at: index)
        } else if selection.count < Self.maxSelection {
            selection.append(profile)
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
    ScrollView {
        CreativeProfilePicker(selection: $selection)
            .padding()
    }
    .background(Palette.bg)
    .preferredColorScheme(.light)
}

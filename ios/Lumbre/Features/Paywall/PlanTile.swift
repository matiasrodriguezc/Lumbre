import LumbreDesign
import SwiftUI

/// Componente PlanTile (`design/system/components/PlanTile`): opción de plan en el paywall.
/// Recomendado: borde 2px `pro` y badge `pro`/`on-pro`. El resto: borde `border-strong`.
/// El precio llega localizado desde la tienda.
struct PlanTile: View {
    let name: LocalizedStringKey
    let price: String
    let period: LocalizedStringKey
    let detail: Text
    var badge: Text? = nil
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Space.s3) {
                VStack(alignment: .leading, spacing: Space.s1) {
                    if let badge {
                        badge
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.onPro)
                            .padding(.horizontal, Space.s2)
                            .padding(.vertical, 2)
                            .background(Palette.pro, in: Capsule())
                            .padding(.bottom, Space.s1)
                    }
                    HStack(alignment: .top) {
                        Text(name)
                            .font(.headline)
                            .foregroundStyle(Palette.ink)
                        if isLargeText {
                            Spacer(minLength: Space.s2)
                            check
                        }
                    }
                    // Con tamaños de accesibilidad, el período va abajo del precio y la marca sube al lado del nombre:
                    // con las dos al costado, el precio se partía o se cortaba.
                    let priceLayout = isLargeText
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                        : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Space.s1))
                    priceLayout {
                        Text(verbatim: price)
                            .lumbreDisplay(.title1)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(period)
                            .font(.callout)
                            .foregroundStyle(Palette.inkMuted)
                    }
                    detail
                        .font(.footnote)
                        .foregroundStyle(Palette.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !isLargeText {
                    check
                }
            }
            .padding(Space.s4)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(isSelected ? Palette.pro : Palette.borderStrong, lineWidth: isSelected ? 2 : 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private var isLargeText: Bool { dynamicTypeSize.isAccessibilitySize }

    private var check: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundStyle(isSelected ? Palette.pro : Palette.borderStrong)
            .accessibilityHidden(true)
    }
}

/// Placeholder mientras carga el precio de la tienda.
struct PlanTilePlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(verbatim: "Anual").font(.headline)
            Text(verbatim: "US$ 00,00").lumbreDisplay(.title1)
            Text(verbatim: "US$ 0,00 por mes").font(.footnote)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s4)
        .redacted(reason: .placeholder)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(Palette.border, lineWidth: 1.5)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: Space.s3) {
        PlanTile(name: "Anual", price: "US$ 49,99", period: "por año", detail: Text("US$ 4,17 por mes · 7 días gratis"), badge: Text("Ahorrás 40%"), isSelected: true) {}
        PlanTile(name: "Mensual", price: "US$ 6,99", period: "por mes", detail: Text("Cancelás cuando quieras"), isSelected: false) {}
        PlanTilePlaceholder()
    }
    .padding()
    .background(Palette.bg)
    .preferredColorScheme(.light)
}

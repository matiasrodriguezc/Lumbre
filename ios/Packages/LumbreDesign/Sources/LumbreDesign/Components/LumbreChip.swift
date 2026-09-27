import SwiftUI

/// Pill para dominios y filtros. Los dominios no llevan un color cada uno: se distinguen por texto e ícono.
public struct LumbreChip: View {
    public enum Variant: Sendable {
        /// Dominio de un concepto.
        case plain
        /// Filtro sin elegir.
        case select
        /// Filtro elegido.
        case on
    }

    let title: String
    let systemImage: String?
    let variant: Variant

    public init(_ title: String, systemImage: String? = nil, variant: Variant = .plain) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
    }

    public var body: some View {
        HStack(spacing: Space.s1) {
            if let systemImage {
                Image(systemName: systemImage).imageScale(.small)
            }
            Text(title)
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(variant == .on ? Palette.accentText : Palette.ink)
        .padding(.horizontal, Space.s3)
        .padding(.vertical, 6)
        .background {
            let shape = Capsule()
            switch variant {
            case .plain: shape.fill(Palette.surfaceAlt)
            case .select: shape.strokeBorder(Palette.borderStrong, lineWidth: 1)
            case .on: shape.fill(Palette.accentSoft).overlay(shape.strokeBorder(Palette.accent, lineWidth: 1))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(variant == .on ? .isSelected : [])
    }
}

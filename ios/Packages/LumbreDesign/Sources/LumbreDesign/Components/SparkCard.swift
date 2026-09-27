import SwiftUI

/// Uno de los dos conceptos que chocan en una chispa.
public struct SparkSide: Sendable {
    public let category: String
    public let categorySymbol: String
    public let title: String

    public init(category: String, categorySymbol: String, title: String) {
        self.category = category
        self.categorySymbol = categorySymbol
        self.title = title
    }
}

/// La chispa del día: A × B, la idea que resulta y sus acciones. Es la única tarjeta con `radius-lg` y `glow-spark`.
public struct SparkCard<Actions: View>: View {
    let a: SparkSide
    let b: SparkSide
    let title: String
    let explanation: String
    let actions: Actions

    public init(a: SparkSide, b: SparkSide, title: String, explanation: String, @ViewBuilder actions: () -> Actions) {
        self.a = a
        self.b = b
        self.title = title
        self.explanation = explanation
        self.actions = actions()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.s5) {
            HStack(alignment: .top, spacing: Space.s2) {
                side(a)
                Text("×")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.inkMuted)
                    .padding(.top, Space.s5)
                    .accessibilityHidden(true)
                side(b)
            }
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: Space.s3) {
                Text(title)
                    .lumbreDisplay(.sparkHero)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(explanation)
                    .font(.body)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actions
        }
        .padding(Space.s5)
        .background {
            // La sombra va en el fondo y no en la tarjeta entera, para que no se replique en cada elemento de adentro.
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Palette.surface)
                .lumbreShadow(.glowSpark)
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
    }

    private func side(_ side: SparkSide) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Label(side.category, systemImage: side.categorySymbol)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.inkMuted)
            Text(side.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s3)
        .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }
}

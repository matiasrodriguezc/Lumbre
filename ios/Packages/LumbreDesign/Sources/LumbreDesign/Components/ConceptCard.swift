import SwiftUI

/// El átomo de la red: una neurona con categoría, título, tesis en una frase y fuente. Nunca muestra el texto crudo.
public struct ConceptCard: View {
    let category: String
    let categorySymbol: String
    let title: String
    let thesis: String
    let source: Text

    public init(category: String, categorySymbol: String, title: String, thesis: String, source: Text) {
        self.category = category
        self.categorySymbol = categorySymbol
        self.title = title
        self.thesis = thesis
        self.source = source
    }

    @Environment(\.neuralIdentity) private var neuralIdentity

    public var body: some View {
        if neuralIdentity { node } else { card }
    }

    /// Una neurona colgada del axón de la lista: el nodo es la neurona chica; sin tarjeta.
    private var node: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(category, systemImage: categorySymbol)
                .font(.footnote)
                .foregroundStyle(Palette.inkMuted)
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text(thesis)
                .font(.callout)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            source
                .font(.footnote)
                .foregroundStyle(Palette.inkMuted)
                .padding(.top, 2)
        }
        .padding(.vertical, Space.s1)
        .axonRow { MiniNeuron() }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            LumbreChip(category, systemImage: categorySymbol)
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text(thesis)
                .font(.callout)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            source
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s4)
        .background {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Palette.surface)
                .lumbreShadow(.elevCard)
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

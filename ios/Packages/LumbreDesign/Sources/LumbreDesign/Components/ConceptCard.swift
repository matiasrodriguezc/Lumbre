import SwiftUI

/// El átomo de la bóveda: dominio, título, tesis en una frase y fuente. Nunca muestra el texto crudo.
public struct ConceptCard: View {
    let domain: String
    let domainSymbol: String
    let title: String
    let thesis: String
    let source: Text

    public init(domain: String, domainSymbol: String, title: String, thesis: String, source: Text) {
        self.domain = domain
        self.domainSymbol = domainSymbol
        self.title = title
        self.thesis = thesis
        self.source = source
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            LumbreChip(domain, systemImage: domainSymbol)
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

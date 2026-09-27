import SwiftUI

/// Contador de chispas de hoy y cuándo se recarga. Vive arriba en Hoy y en el widget.
public struct SparkMeter: View {
    let available: Int
    let total: Int
    let status: Text
    let detail: Text

    public init(available: Int, total: Int, status: Text, detail: Text) {
        self.available = available
        self.total = total
        self.status = status
        self.detail = detail
    }

    public var body: some View {
        HStack(alignment: .center, spacing: Space.s4) {
            VStack(alignment: .leading, spacing: Space.s1) {
                status
                    .font(.headline)
                    .foregroundStyle(available > 0 ? Palette.accentText : Palette.ink)
                detail
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.inkMuted)
            }
            Spacer(minLength: 0)
            Text("\(available)/\(total)")
                .lumbreDisplay(.counter)
                .foregroundStyle(available > 0 ? Palette.accentText : Palette.inkMuted)
                .padding(.horizontal, Space.s4)
                .padding(.vertical, Space.s1)
                .background(available > 0 ? Palette.accentSoft : Palette.surfaceAlt, in: Capsule())
        }
        .padding(Space.s4)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

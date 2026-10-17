import SwiftUI

/// Contador de chispas de hoy y cuándo se recarga. Vive arriba en Hoy y en el widget.
/// Con la identidad neuronal es una línea: una neurona chica (negra con el núcleo rosa si hay chispa para encender,
/// dormida si no), el estado y, a la derecha, las neuronas que faltan guardar para ganar una extra.
public struct SparkMeter: View {
    let available: Int
    let total: Int
    let status: Text
    let detail: Text
    /// Neuronas guardadas hoy hacia la próxima extra, de `goal`. Nil si no aplica (Pro, invitado).
    let earned: Int?
    let goal: Int

    @Environment(\.neuralIdentity) private var neuralIdentity

    public init(available: Int, total: Int, status: Text, detail: Text, earned: Int? = nil, goal: Int = 3) {
        self.available = available
        self.total = total
        self.status = status
        self.detail = detail
        self.earned = earned
        self.goal = goal
    }

    public var body: some View {
        if neuralIdentity { line } else { card }
    }

    private var line: some View {
        HStack(alignment: .center, spacing: Space.s3) {
            MiniNeuron(isLit: available > 0, isDim: available == 0)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                status
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                detail
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
            }
            Spacer(minLength: 0)
            if let earned {
                HStack(spacing: 2) {
                    ForEach(0..<goal, id: \.self) { i in
                        MiniNeuron(isDim: i >= earned).frame(width: 18, height: 18)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(earned) de \(goal) neuronas para la próxima chispa extra"))
            }
        }
        .padding(.vertical, Space.s3)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var card: some View {
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

#Preview {
    VStack(spacing: Space.s4) {
        SparkMeter(available: 1, total: 1, status: Text("1 chispa para encender"), detail: Text(verbatim: "Se recarga mañana a las 08:00"), earned: 1)
        SparkMeter(available: 0, total: 1, status: Text("Chispa de hoy encendida"), detail: Text(verbatim: "La próxima, mañana a las 08:00"))
    }
    .padding()
    .background(Palette.bg)
}

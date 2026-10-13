import LumbreCore
import LumbreDesign
import SwiftUI

/// Wordmark: "Lumbre" en Fraunces seguido de un punto `spark`. El punto es parte de la marca.
struct Wordmark: View {
    var style: DisplayStyle = .sparkHero

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text(verbatim: "Lumbre")
                .lumbreDisplay(style)
                .foregroundStyle(Palette.ink)
            Circle()
                .fill(Palette.spark)
                .frame(width: dotSize, height: dotSize)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Lumbre"))
        .accessibilityAddTraits(.isHeader)
    }

    @ScaledMetric(relativeTo: .largeTitle) private var dotSize: CGFloat = 8
}

/// Ícono de sección de la identidad neuronal: Hoy es una neurona, Red tus neuronas conectadas y Circuitos
/// los proyectos. Sin el flag `neural_identity`, el símbolo del sistema de antes.
struct SectionIcon: View {
    enum Kind {
        case today, network, circuit

        var asset: String {
            switch self {
            case .today: "tab-hoy"
            case .network: "tab-red"
            case .circuit: "tab-circuitos"
            }
        }

        var symbol: String {
            switch self {
            case .today: "sparkles"
            case .network: "square.stack.3d.up"
            case .circuit: "square.grid.2x2"
            }
        }
    }

    let kind: Kind
    @Environment(\.neuralIdentity) private var neuralIdentity

    init(_ kind: Kind) {
        self.kind = kind
    }

    var body: some View {
        if neuralIdentity {
            Image(kind.asset)
        } else {
            Image(systemName: kind.symbol)
        }
    }
}

/// Links legales. URLs provisorias hasta que estén publicadas.
enum LegalLinks {
    static let privacy = URL(string: "https://lumbre.app/privacidad")!
    static let terms = URL(string: "https://lumbre.app/terminos")!
}

/// La cuenta real (Apple, Google, email) llega en la etapa siguiente. Mientras, se explica y se sigue como invitado.
struct AccountComingSoonSheet: View {
    /// Texto del botón principal: "Seguir como invitado" en el onboarding, "Entendido" en Perfil.
    var continueTitle: LocalizedStringKey = "Seguir como invitado"
    var onContinue: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s4) {
                    Image(systemName: "person.crop.circle.badge.clock")
                        .font(.largeTitle)
                        .foregroundStyle(Palette.infoText)
                        .accessibilityHidden(true)
                    Text("Las cuentas llegan pronto")
                        .lumbreDisplay(.title2)
                        .foregroundStyle(Palette.ink)
                    Text("Muy pronto vas a poder entrar con Apple, Google o tu email y tener tus ideas en todos tus dispositivos.")
                        .font(.body)
                        .foregroundStyle(Palette.ink)
                    Text("Mientras tanto, usás Lumbre como invitado. Todo lo que guardes queda en esta sesión y pasa a tu cuenta cuando la crees.")
                        .font(.callout)
                        .foregroundStyle(Palette.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.s4)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    dismiss()
                    onContinue()
                } label: {
                    Text(continueTitle)
                }
                .buttonStyle(.lumbre(.secondary, fullWidth: true))
                .padding(.horizontal, Space.s4)
                .padding(.bottom, Space.s2)
            }
            .background(Palette.surface)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(Radius.lg)
    }
}

#Preview("Wordmark") {
    Wordmark()
        .padding()
        .background(Palette.bg)
        .preferredColorScheme(.dark)
}

#Preview("Cuenta") {
    Color.clear.sheet(isPresented: .constant(true)) { AccountComingSoonSheet() }
        .preferredColorScheme(.dark)
}

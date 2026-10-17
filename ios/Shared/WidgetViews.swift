import LumbreCore
import LumbreDesign
import SwiftUI
import WidgetKit

// Vistas de los widgets (paso 55). Están en la carpeta compartida para que la app pueda renderizarlas
// a imagen en Debug (`-renderWidgetSnapshots`, ver WidgetGallery.swift); el widget las usa tal cual.
//
// Identidad: la chispa del día no va en tarjeta; las dos neuronas a los costados de la sinapsis y el título en
// Fraunces. El rosa aparece solo en la estrella de la sinapsis (entre las terminales negras) y en el núcleo de la neurona.

/// Widget "Chispa de hoy" en todas sus familias.
struct TodaySparkWidgetView: View {
    let state: TodayWidgetState
    let family: WidgetFamily
    var isEnabled = true

    var body: some View {
        Group {
            if !isEnabled {
                UnavailableView(family: family)
            } else {
                switch family {
                case .systemSmall: small
                case .systemMedium: medium
                case .accessoryRectangular: rectangular
                case .accessoryInline: inline
                case .accessoryCircular: QuickCaptureWidgetView(family: family)
                default: large
                }
            }
        }
        .widgetURL(state.sparkID.map { LumbreDeepLink.spark($0, entry: "widget").url } ?? LumbreDeepLink.today.url)
    }

    // MARK: Pantalla de inicio

    private var small: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            WidgetCaption(text: extensionsText("Chispa de hoy"))
            Synapse(stage)
                .frame(height: 20)
            Spacer(minLength: 0)
            headline(size: 20, lines: 3)
            if let pair {
                Text(pair)
                    .font(.caption2)
                    .foregroundStyle(Palette.inkMuted)
                    .lineLimit(1)
            } else {
                detail.lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            if let snapshot {
                HStack(alignment: .center, spacing: Space.s2) {
                    NeuronName(concept: snapshot.conceptA, alignment: .leading)
                    Synapse(stage)
                        .frame(width: 66, height: 22)
                    NeuronName(concept: snapshot.conceptB, alignment: .trailing)
                }
            } else {
                WidgetCaption(text: extensionsText("Chispa de hoy"))
                Synapse(stage)
                    .frame(height: 22)
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: Space.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    headline(size: 22, lines: 2)
                    if snapshot == nil || state.isPendingSpark {
                        detail.lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                CaptureButton(size: 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            WidgetCaption(text: extensionsText("Chispa de hoy"))
            if let snapshot {
                HStack(alignment: .top, spacing: Space.s3) {
                    NeuronName(concept: snapshot.conceptA, alignment: .leading)
                    NeuronName(concept: snapshot.conceptB, alignment: .trailing)
                }
            }
            Synapse(stage, full: true)
                .frame(maxWidth: 260)
                .frame(maxWidth: .infinity)
            headline(size: 28, lines: 3)
            if case .spark(let snapshot) = state {
                Text(snapshot.body)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(4)
            } else {
                detail.lineLimit(3)
            }
            Spacer(minLength: 0)
            CaptureLink {
                Label(extensionsText("Guardar una idea"), systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, Space.s4)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Palette.accent, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Pantalla bloqueada

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(extensionsText("Chispa de hoy"), systemImage: "sparkle")
                .font(.caption2.weight(.semibold))
                .widgetAccentable()
            Group {
                switch state {
                case .spark(let snapshot): Text(snapshot.title)
                case .pending: Text(extensionsText("Lista para encender"))
                case .ready: Text(extensionsText("Ya está lista"))
                case .waiting(let date): Text(date, style: .time)
                case .empty: Text(extensionsText("Abrí Lumbre"))
                }
            }
            .font(.headline)
            .lineLimit(2)
            .privacySensitive()
            if let pair {
                Text(pair)
                    .font(.caption2)
                    .lineLimit(1)
                    .privacySensitive()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Label {
            switch state {
            case .spark(let snapshot): Text(snapshot.title).privacySensitive()
            case .pending, .ready: Text(extensionsText("Tu chispa está lista"))
            case .waiting(let date): Text(extensionsText("Próxima chispa")) + Text(" ") + Text(date, style: .time)
            case .empty: Text(extensionsText("Chispa de hoy"))
            }
        } icon: {
            Image(systemName: "sparkle")
        }
    }

    // MARK: Piezas

    private var snapshot: LumbreShared.TodaySnapshot? {
        switch state {
        case .spark(let snapshot), .pending(let snapshot): snapshot
        default: nil
        }
    }

    /// "A × B", como se escribe la chispa.
    private var pair: String? {
        snapshot.map { "\($0.conceptA.title) × \($0.conceptB.title)" }
    }

    /// La sinapsis encendida solo cuando la chispa ya se reveló; antes, las terminales separadas.
    private var stage: Synapse.Stage {
        if case .spark = state { .lit } else { .apart }
    }

    @ViewBuilder
    private func headline(size: CGFloat, lines: Int) -> some View {
        let text: String = switch state {
        case .spark(let snapshot): snapshot.title
        case .pending: extensionsText("Tu chispa está lista")
        case .ready: extensionsText("Tu chispa de hoy ya está lista")
        case .waiting: extensionsText("Tu próxima chispa")
        case .empty: extensionsText("Tu chispa de hoy")
        }
        Text(text)
            .font(Font(LumbreFont.uiDisplay(.sparkHero, size: size) as CTFont))
            .foregroundStyle(Palette.ink)
            .lineLimit(lines)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
            .privacySensitive()
    }

    @ViewBuilder
    private var detail: some View {
        Group {
            switch state {
            case .spark, .pending: Text(extensionsText("Tocá para encenderla"))
            case .ready: Text(extensionsText("Abrí Lumbre para encenderla"))
            case .waiting(let date): Text(extensionsText("Llega a las")) + Text(" ") + Text(date, style: .time)
            case .empty: Text(extensionsText("Abrí Lumbre para ver la chispa del día"))
            }
        }
        .font(.caption)
        .foregroundStyle(Palette.inkMuted)
    }
}

private extension TodayWidgetState {
    var isPendingSpark: Bool {
        if case .pending = self { true } else { false }
    }
}

/// Widget "Guardar una idea": abre Capturar.
struct QuickCaptureWidgetView: View {
    let family: WidgetFamily
    var isEnabled = true

    var body: some View {
        Group {
            if !isEnabled {
                UnavailableView(family: family)
            } else if family == .accessoryCircular {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .widgetAccentable()
                }
                .accessibilityLabel(Text(extensionsText("Guardar una idea en Lumbre")))
            } else {
                VStack(alignment: .leading, spacing: Space.s1) {
                    ZStack {
                        Circle().fill(Palette.accent)
                        Image(systemName: "plus")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Palette.onAccent)
                    }
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)
                    Spacer(minLength: 0)
                    Text(extensionsText("Guardar una idea"))
                        .font(Font(LumbreFont.uiDisplay(.title2, size: 20) as CTFont))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(extensionsText("Va directo a tu Red"))
                        .font(.caption)
                        .foregroundStyle(Palette.inkMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .widgetURL(LumbreDeepLink.capture(entry: "widget").url)
    }
}

/// Con el feature flag apagado.
private struct UnavailableView: View {
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline, .accessoryCircular, .accessoryRectangular:
            Text(extensionsText("Pronto en Lumbre"))
        default:
            VStack(alignment: .leading, spacing: Space.s2) {
                MiniNeuron(isDim: true).frame(width: 28, height: 28)
                Spacer(minLength: 0)
                Text(extensionsText("Pronto en Lumbre"))
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private struct WidgetCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Palette.inkMuted)
            .lineLimit(1)
    }
}

/// Nombre de una de las dos neuronas: categoría arriba, título abajo.
private struct NeuronName: View {
    let concept: LumbreShared.TodaySnapshot.ConceptSummary
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 1) {
            if let category = concept.category {
                Text(category)
                    .font(.caption2)
                    .foregroundStyle(Palette.inkMuted)
                    .lineLimit(1)
            }
            Text(concept.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        .privacySensitive()
    }
}

/// Link a Capturar (en el widget chico no hay links: todo el widget abre su `widgetURL`).
private struct CaptureLink<Label: View>: View {
    @ViewBuilder let label: Label

    var body: some View {
        Link(destination: LumbreDeepLink.capture(entry: "widget").url) { label }
            .accessibilityLabel(Text(extensionsText("Guardar una idea")))
    }
}

/// Botón principal redondo: negro (`accent`) con el + en `on-accent`.
private struct CaptureButton: View {
    let size: CGFloat

    var body: some View {
        CaptureLink {
            Image(systemName: "plus")
                .font(.headline)
                .foregroundStyle(Palette.onAccent)
                .frame(width: size, height: size)
                .background(Palette.accent, in: Circle())
        }
    }
}

extension LumbreShared {
    /// Esquema de color que eligió el usuario en Perfil (gris por defecto, como la app).
    static var widgetColorScheme: ColorScheme? {
        (theme.flatMap(ThemePreference.init(rawValue:)) ?? .light).colorScheme
    }
}

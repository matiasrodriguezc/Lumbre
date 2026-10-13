import SwiftUI

// Identidad neuronal (design/system/README.md, "Mundo neuronal"; guía visual en design/system/identidad.html).
// Las formas salen de design/system/identidad/generar.py, en NeuralArt.generated.swift.

extension EnvironmentValues {
    /// Activa la identidad neuronal en los componentes (sinapsis en vez de "×"). La app lo ata al flag `neural_identity`.
    @Entry public var neuralIdentity: Bool = true
}

// MARK: Datos

/// Rol de una capa de ilustración. El color sale de los tokens, así que funciona igual en los dos temas.
public enum NeuralRole: Sendable {
    case dormant, link, active, impulse, spark, trace

    public var color: Color {
        switch self {
        case .dormant: Palette.surfaceAlt
        case .link: Palette.border
        case .active: Palette.ink
        case .impulse: Palette.infoText
        case .spark: Palette.spark
        case .trace: Palette.borderStrong
        }
    }
}

/// Una capa: anillos de polígonos como pares x, y planos. Los anillos interiores son huecos (relleno par-impar).
public struct NeuralLayer: Sendable {
    public let role: NeuralRole
    let rings: [[Double]]

    init(_ role: NeuralRole, _ rings: [[Double]]) {
        self.role = role
        self.rings = rings
    }
}

/// Una ilustración en el espacio de su lienzo original.
public struct NeuralArt: Sendable {
    public let size: CGSize
    public let layers: [NeuralLayer]

    init(width: Double, height: Double, layers: [NeuralLayer]) {
        self.size = CGSize(width: width, height: height)
        self.layers = layers
    }
}

/// Encaja un lienzo en un rect sin deformarlo: `.fit` lo muestra entero, `.fill` lo recorta.
struct NeuralFrame {
    let scale: CGFloat
    let origin: CGPoint

    init(canvas: CGSize, in rect: CGRect, mode: ContentMode = .fit) {
        let sx = rect.width / canvas.width, sy = rect.height / canvas.height
        scale = mode == .fit ? min(sx, sy) : max(sx, sy)
        origin = CGPoint(x: rect.midX - canvas.width * scale / 2, y: rect.midY - canvas.height * scale / 2)
    }

    func point(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
    }
}

/// Los anillos de una capa como `Shape`.
public struct NeuralShape: Shape {
    let rings: [[Double]]
    let canvas: CGSize
    var mode: ContentMode = .fit

    public func path(in rect: CGRect) -> Path {
        let frame = NeuralFrame(canvas: canvas, in: rect, mode: mode)
        var path = Path()
        for ring in rings where ring.count >= 6 {
            path.move(to: frame.point(ring[0], ring[1]))
            for i in stride(from: 2, to: ring.count - 1, by: 2) {
                path.addLine(to: frame.point(ring[i], ring[i + 1]))
            }
            path.closeSubpath()
        }
        return path
    }
}

/// Un círculo en coordenadas del lienzo (el núcleo del símbolo, el impulso).
struct NeuralDot: Shape {
    let center: CGPoint
    let radius: CGFloat
    let canvas: CGSize

    func path(in rect: CGRect) -> Path {
        let frame = NeuralFrame(canvas: canvas, in: rect)
        let c = frame.point(center.x, center.y), r = radius * frame.scale
        return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }
}

private struct NeuralLayers: View {
    let art: NeuralArt
    var mode: ContentMode = .fit

    var body: some View {
        ZStack {
            ForEach(art.layers.indices, id: \.self) { i in
                let layer = art.layers[i]
                NeuralShape(rings: layer.rings, canvas: art.size, mode: mode)
                    .fill(layer.role.color, style: FillStyle(eoFill: true))
            }
        }
    }
}

// MARK: Símbolo

/// El símbolo de marca: la neurona. Largo para el wordmark y el splash; compacto para espacios cuadrados.
/// No es un ícono de interfaz.
public struct LumbreMark: View {
    public enum Variant: Sendable { case long, compact }

    let variant: Variant
    let showsNucleus: Bool

    /// `showsNucleus` pinta el núcleo en `spark`. Solo si no hay otro magenta protagonista cerca (con el wordmark, no).
    public init(_ variant: Variant = .long, showsNucleus: Bool = false) {
        self.variant = variant
        self.showsNucleus = showsNucleus
    }

    public var body: some View {
        let art = variant == .long ? NeuralArt.markLong : NeuralArt.markCompact
        ZStack {
            NeuralLayers(art: art)
            if showsNucleus {
                NeuralDot(center: variant == .long ? NeuralAnchors.markLongNucleus : NeuralAnchors.markCompactNucleus,
                          radius: variant == .long ? 8 : 5.2, canvas: art.size)
                    .fill(Palette.spark)
            }
        }
        .aspectRatio(art.size, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Neurona chica: el estado de la chispa en el contador y el nodo de una neurona en las listas.
/// `isLit` le pone el núcleo `spark` (el rosa siempre va sobre la neurona negra); `isDim` la deja dormida.
public struct MiniNeuron: View {
    let isLit: Bool
    let isDim: Bool

    public init(isLit: Bool = false, isDim: Bool = false) {
        self.isLit = isLit
        self.isDim = isDim
    }

    public var body: some View {
        let art = NeuralArt.markCompact
        ZStack {
            NeuralShape(rings: art.layers[0].rings, canvas: art.size)
                .fill(isDim ? Palette.border : Palette.ink)
            if isLit && !isDim {
                NeuralDot(center: NeuralAnchors.markCompactNucleus, radius: 7, canvas: art.size)
                    .fill(Palette.spark)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Fila colgada de un axón: una línea vertical `border` une los nodos de una lista (Anteriores, la Red).
struct AxonRow<Node: View>: ViewModifier {
    let spacing: CGFloat
    let node: Node

    func body(content: Content) -> some View {
        HStack(alignment: .top, spacing: Space.s3) {
            node.frame(width: 28, height: 28)
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(alignment: .topLeading) {
            Rectangle()
                .fill(Palette.border)
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .padding(.leading, 13)
                .padding(.vertical, -spacing / 2)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    /// Cuelga la fila de un axón con `node` como nodo. `spacing` es el espacio entre filas, para que la línea no se corte.
    public func axonRow<Node: View>(spacing: CGFloat = Space.s3, @ViewBuilder node: () -> Node) -> some View {
        modifier(AxonRow(spacing: spacing, node: node()))
    }
}

// MARK: Sinapsis

/// Dos terminales enfrentadas y, en el hueco, la chispa. Va entre las dos neuronas de una chispa.
/// `apart`: todavía no se tocaron; `reaching`: las terminales salen y viaja el impulso; `lit`: salta la chispa.
/// `full` dibuja las dos neuronas enteras (la chispa, el reveal, compartir); sin él, solo las terminales (conectores chicos).
public struct Synapse: View {
    public enum Stage: Sendable { case apart, reaching, lit }

    let stage: Stage
    let full: Bool

    public init(_ stage: Stage = .lit, full: Bool = false) {
        self.stage = stage
        self.full = full
    }

    public var body: some View {
        let left = full ? NeuralArt.synapseFullLeft : NeuralArt.synapseLeft
        let right = full ? NeuralArt.synapseFullRight : NeuralArt.synapseRight
        let canvas = left.size
        let mid = canvas.width / 2
        // Dónde arranca el impulso y dónde llega, en coordenadas del lienzo.
        let (from, to): (Double, Double) = full ? (40, mid - 12) : (10, mid - 10)
        let starSize: Double = full ? 22 : 17
        GeometryReader { proxy in
            let frame = NeuralFrame(canvas: canvas, in: CGRect(origin: .zero, size: proxy.size))
            let apartShift = full && stage == .apart ? 10 * frame.scale : 0
            ZStack {
                NeuralShape(rings: left.layers[0].rings, canvas: canvas)
                    .fill(Palette.ink)
                    .scaleEffect(x: !full && stage == .apart ? 0.7 : 1, anchor: .leading)
                    .offset(x: -apartShift)
                NeuralShape(rings: right.layers[0].rings, canvas: canvas)
                    .fill(Palette.ink)
                    .scaleEffect(x: !full && stage == .apart ? 0.7 : 1, anchor: .trailing)
                    .offset(x: apartShift)
                ForEach(0..<2, id: \.self) { side in
                    let x = stage == .lit ? to : from
                    Circle()
                        .fill(Palette.infoText)
                        .frame(width: 5 * frame.scale, height: 5 * frame.scale)
                        .position(frame.point(side == 0 ? x : canvas.width - x, canvas.height / 2))
                        .opacity(stage == .reaching ? 1 : 0)
                }
                SparkStar()
                    .fill(Palette.spark)
                    .frame(width: starSize * frame.scale, height: starSize * frame.scale)
                    .position(frame.point(mid, canvas.height / 2))
                    .scaleEffect(stage == .lit ? 1 : 0.1)
                    .opacity(stage == .lit ? 1 : 0)
            }
        }
        .aspectRatio(canvas, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

// MARK: Pulso

/// Indicador de carga propio para destilar y encender: un impulso recorre un axón en 1,2 s.
/// Para cualquier otra carga, el `ProgressView` del sistema. Con Reducir movimiento, el impulso queda quieto.
public struct ImpulseLoader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        let art = NeuralArt.axon
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0.5 : context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.2) / 1.2
            let eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            ZStack {
                NeuralLayers(art: art)
                NeuralDot(center: Self.point(at: eased), radius: 3.4, canvas: art.size)
                    .fill(Palette.infoText)
            }
        }
        .aspectRatio(art.size, contentMode: .fit)
        .frame(maxWidth: 120)
        .accessibilityHidden(true)
    }

    /// Punto a la fracción `t` del largo del axón.
    static func point(at t: Double) -> CGPoint {
        let path = NeuralAnchors.axonPath
        let lengths = zip(path, path.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
        var remaining = t * lengths.reduce(0, +)
        for (i, length) in lengths.enumerated() {
            if remaining <= length || i == lengths.count - 1 {
                let f = length > 0 ? min(remaining / length, 1) : 0
                return CGPoint(x: path[i].x + (path[i + 1].x - path[i].x) * f, y: path[i].y + (path[i + 1].y - path[i].y) * f)
            }
            remaining -= length
        }
        return path[0]
    }
}

// MARK: Ilustraciones

/// Ilustraciones de estados vacíos y fondos de red. Siempre decorativas: el texto va aparte.
public struct NeuralIllustration: View {
    public enum Kind: Sendable {
        /// Bóveda vacía: una neurona sola.
        case emptyVault
        /// Antes de la chispa: dos neuronas que se buscan.
        case beforeSpark
        /// Sin conexión: un axón cortado.
        case offline
        /// Sin circuitos: tres neuronas con una conexión todavía abierta.
        case emptyCircuits
    }

    let kind: Kind

    public init(_ kind: Kind) {
        self.kind = kind
    }

    public var body: some View {
        let art: NeuralArt = switch kind {
        case .emptyVault: .emptyVault
        case .beforeSpark: .beforeSpark
        case .offline: .offline
        case .emptyCircuits: .emptyCircuits
        }
        NeuralLayers(art: art)
            .aspectRatio(art.size, contentMode: .fit)
            .frame(maxWidth: 220)
            .accessibilityHidden(true)
    }
}

/// La red de fondo: neuronas dormidas unidas a sus vecinas. Para splash, onboarding y encabezados;
/// nunca detrás de listas ni texto corrido, y nunca animada.
public struct NeuralNetworkBackground: View {
    public enum Density: Sendable {
        /// Lienzo vertical, neuronas grandes: splash y onboarding.
        case tall
        /// Lienzo apaisado, neuronas chicas: encabezados.
        case quiet
    }

    let density: Density

    public init(_ density: Density = .tall) {
        self.density = density
    }

    public var body: some View {
        NeuralLayers(art: density == .tall ? .networkTall : .networkQuiet, mode: .fill)
            .clipped()
            .accessibilityHidden(true)
    }
}

/// Fondo de pantalla de marca: `bg` con la red dormida arriba, que se desvanece hacia el contenido.
/// Con la identidad neuronal apagada queda solo `bg`.
struct NeuralScreenBackground: ViewModifier {
    var height: CGFloat
    @Environment(\.neuralIdentity) private var neuralIdentity

    func body(content: Content) -> some View {
        content.background {
            ZStack(alignment: .top) {
                Palette.bg
                if neuralIdentity {
                    NeuralNetworkBackground(.quiet)
                        .frame(height: height)
                        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.45),
                                                     .init(color: .clear, location: 1)],
                                             startPoint: .top, endPoint: .bottom))
                }
            }
            .ignoresSafeArea()
        }
    }
}

extension View {
    /// Fondo de las pantallas principales: la noche con la red de neuronas dormidas en la franja de arriba.
    public func neuralBackground(height: CGFloat = 320) -> some View {
        modifier(NeuralScreenBackground(height: height))
    }
}

#Preview("Identidad neuronal") {
    ScrollView {
        VStack(spacing: Space.s6) {
            LumbreMark(.long, showsNucleus: true).frame(width: 200)
            LumbreMark(.compact).frame(width: 96)
            HStack(spacing: Space.s4) {
                Synapse(.apart)
                Synapse(.reaching)
                Synapse(.lit)
            }
            .frame(height: 30)
            ImpulseLoader()
            NeuralIllustration(.emptyVault)
            NeuralIllustration(.beforeSpark)
            NeuralIllustration(.offline)
            NeuralNetworkBackground(.quiet).frame(height: 140)
        }
        .padding()
    }
    .background(Palette.bg)
    .preferredColorScheme(.light)
}

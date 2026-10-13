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

// MARK: Sinapsis

/// Dos terminales enfrentadas y, en el hueco, la chispa. Va entre los dos conceptos de una chispa.
/// `apart`: todavía no se tocaron; `reaching`: las terminales salen y viaja el impulso; `lit`: salta la chispa.
public struct Synapse: View {
    public enum Stage: Sendable { case apart, reaching, lit }

    let stage: Stage

    public init(_ stage: Stage = .lit) {
        self.stage = stage
    }

    public var body: some View {
        let canvas = NeuralArt.synapseLeft.size
        GeometryReader { proxy in
            let frame = NeuralFrame(canvas: canvas, in: CGRect(origin: .zero, size: proxy.size))
            let impulseX = stage == .lit ? 50.0 : 10.0
            ZStack {
                NeuralShape(rings: NeuralArt.synapseLeft.layers[0].rings, canvas: canvas)
                    .fill(Palette.ink)
                    .scaleEffect(x: stage == .apart ? 0.7 : 1, anchor: .leading)
                NeuralShape(rings: NeuralArt.synapseRight.layers[0].rings, canvas: canvas)
                    .fill(Palette.ink)
                    .scaleEffect(x: stage == .apart ? 0.7 : 1, anchor: .trailing)
                ForEach(0..<2, id: \.self) { side in
                    Circle()
                        .fill(Palette.infoText)
                        .frame(width: 5 * frame.scale, height: 5 * frame.scale)
                        .position(frame.point(side == 0 ? impulseX : 120 - impulseX, 20))
                        .opacity(stage == .reaching ? 1 : 0)
                }
                SparkStar()
                    .fill(Palette.spark)
                    .frame(width: 17 * frame.scale, height: 17 * frame.scale)
                    .position(frame.point(60, 20))
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
    .preferredColorScheme(.dark)
}

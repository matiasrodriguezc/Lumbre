import SwiftUI

// Sinapsis con conos de crecimiento (flag `growth_cones`, design/reveal/README.md §13): en vez de terminales fijas,
// la punta de cada axón es un cono con filopodios que tantean, como en la microscopía de dos neuronas conectándose.
// Antes de encender se tantean de lejos; al encender avanzan, se tocan las puntas y se entrelazan ("apretón de manos").

extension EnvironmentValues {
    /// La sinapsis con conos de crecimiento. La app lo ata al flag `growth_cones`.
    @Entry public var growthCones: Bool = true
}

/// Las dos neuronas con conos de crecimiento, en el lienzo de 240 × 80 de la sinapsis.
/// - `approach`: 0 separadas (se tantean de lejos), 1 tocándose.
/// - `grip`: 0 → 1, los filopodios de adelante se estiran hasta cruzarse con los del otro cono.
/// - `live`: los filopodios se mueven solos (con Reducir movimiento, nunca).
public struct GrowthConeSynapse: View {
    var approach: Double
    var grip: Double
    var enter: Double
    var star: Double
    var starOpacity: Double
    var live: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(approach: Double, grip: Double, enter: Double = 1, star: Double = 1, starOpacity: Double = 1, live: Bool = false) {
        self.approach = approach
        self.grip = grip
        self.enter = enter
        self.star = star
        self.starOpacity = starOpacity
        self.live = live
    }

    public var body: some View {
        let moves = live && !reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !moves)) { timeline in
            let t = moves ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600) : 0
            Canvas { context, size in
                let frame = NeuralFrame(canvas: Self.canvas, in: CGRect(origin: .zero, size: size))
                let shift = 22 * (1 - enter)
                context.opacity = enter
                draw(side: .left, in: &context, frame: frame, t: t, shift: -shift)
                draw(side: .right, in: &context, frame: frame, t: t, shift: shift)
                context.opacity = 1
                if starOpacity > 0 {
                    let r = 11 * max(star, 0) * frame.scale
                    let c = frame.point(Self.mid, Self.contactY)
                    context.opacity = starOpacity
                    context.fill(SparkStar().path(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                                 with: .color(Palette.spark))
                }
            }
        }
        .aspectRatio(Self.canvas, contentMode: .fit)
        .accessibilityHidden(true)
    }

    // MARK: Geometría (unidades del lienzo)

    static let canvas = CGSize(width: 240, height: 80)
    static let mid = 120.0
    static let contactY = 40.0
    /// Hasta dónde se dibuja la neurona estática (soma, dendritas y el arranque del axón); de ahí sale el axón vivo.
    static let somaEdge = 56.0
    static let axonStartY = 38.0

    enum Side { case left, right }

    /// Un filopodio: ángulo respecto del frente del cono (grados), largo y fases propias para que no se muevan juntos.
    struct Filopodium {
        let angle: Double
        let length: Double
        let speed: Double
        let phase: Double
    }

    static let filopodia: [Filopodium] = [
        .init(angle: -84, length: 9, speed: 0.9, phase: 0.3),
        .init(angle: -60, length: 13, speed: 1.3, phase: 2.1),
        .init(angle: -38, length: 17, speed: 0.7, phase: 4.0),
        .init(angle: -16, length: 20, speed: 1.1, phase: 1.2),
        .init(angle: 6, length: 19, speed: 0.8, phase: 5.2),
        .init(angle: 27, length: 16, speed: 1.4, phase: 3.3),
        .init(angle: 50, length: 12, speed: 1.0, phase: 0.8),
        .init(angle: 76, length: 9, speed: 1.2, phase: 2.7),
    ]

    /// Dónde queda el cono: separado (0) y tocándose (1). Tocándose quedan a 16 u del centro, y los filopodios
    /// de adelante cruzan hasta meterse entre los del otro.
    static let coneApart = 80.0, coneTouching = 104.0

    private func draw(side: Side, in context: inout GraphicsContext, frame: NeuralFrame, t: Double, shift: Double) {
        let seed: Double = side == .left ? 0 : 1.7
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            frame.point(side == .left ? x + shift : Self.canvas.width - x + shift, y)
        }
        let ink = GraphicsContext.Shading.color(Palette.ink)
        let a = min(max(approach, 0), 1), g = min(max(grip, 0), 1)
        // Cuánto se mueve todo: tantea con ganas de lejos y se calma al agarrarse.
        let wander = 1 - 0.8 * g
        let k = frame.scale

        // 1. La neurona estática hasta el arranque del axón.
        let art = side == .left ? NeuralArt.synapseFullLeft : NeuralArt.synapseFullRight
        let artRect = CGRect(x: frame.origin.x, y: frame.origin.y, width: Self.canvas.width * k, height: Self.canvas.height * k)
        let x0 = side == .left ? 0 : Self.canvas.width - Self.somaEdge
        let p0 = frame.point(x0, 0), p1 = frame.point(x0 + Self.somaEdge, Self.canvas.height)
        var soma = context
        soma.translateBy(x: shift * k, y: 0)
        soma.clip(to: Path(CGRect(x: p0.x, y: p0.y - 40, width: p1.x - p0.x, height: p1.y - p0.y + 80)))
        soma.fill(NeuralShape(rings: art.layers[0].rings, canvas: Self.canvas).path(in: artRect),
                  with: ink, style: FillStyle(eoFill: true))

        // 2. El cono avanza hacia el centro y deriva un poco en vertical mientras tantea.
        let coneX = Self.coneApart + (Self.coneTouching - Self.coneApart) * a
        let drift = 2.8 * sin(t * 0.45 + seed) * wander * (1 - 0.7 * a)
        let coneY = Self.axonStartY + (Self.contactY - Self.axonStartY) * a + drift

        // 3. El axón: sale desde adentro de la neurona estática y se afina hacia el cono, con una ondulación lenta.
        let startX = Self.somaEdge - 2
        let sway = 3.4 * sin(t * 0.33 + seed * 2) * wander
        let control = (x: (startX + coneX) / 2, y: (Self.axonStartY + coneY) / 2 + sway)
        func axonPoint(_ u: Double) -> (x: Double, y: Double) {
            let v = 1 - u
            return (v * v * startX + 2 * v * u * control.x + u * u * coneX,
                    v * v * Self.axonStartY + 2 * v * u * control.y + u * u * coneY)
        }
        var upper: [CGPoint] = [], lower: [CGPoint] = []
        let steps = 24
        for i in 0...steps {
            let u = Double(i) / Double(steps)
            let p = axonPoint(u)
            // El axón es casi horizontal: alcanza con engrosarlo en vertical.
            // En x = 56 el axón de la neurona estática mide 8,2 u (y 33,9 a 42,1): empalma sin escalón.
            let half = (8.2 - 5.8 * pow(u, 0.6)) / 2
            upper.append(pt(p.x, p.y - half))
            lower.append(pt(p.x, p.y + half))
        }
        var axon = Path()
        axon.addLines(upper + lower.reversed())
        axon.closeSubpath()
        context.fill(axon, with: ink)

        // 4. Los filopodios: se estiran y se retraen a destiempo. Al acercarse apuntan al otro y, al agarrarse,
        //    los de adelante cruzan el centro en abanico (arriba y abajo de la estrella).
        let cone = pt(coneX, coneY)
        var tips: [CGPoint] = []
        for f in Self.filopodia {
            let spread = 1 - 0.3 * a
            let wobble = 10 * sin(t * f.speed * 0.9 + f.phase + seed) * wander
            let degrees = f.angle * spread + wobble
            let angle = degrees * .pi / 180
            let probe = 0.6 + 0.4 * sin(t * f.speed * 1.3 + f.phase * 1.7 + seed)
            var length = f.length * 1.3 * probe
            if abs(f.angle) < 45 {
                // Hasta pasar el centro y meterse entre los filopodios del otro cono.
                let reach = (Self.mid - coneX + 7 + 3 * sin(f.phase)) / max(cos(angle), 0.4)
                length += (reach - length) * g
            } else {
                length *= 1 - 0.3 * g
            }
            let bend = 1.8 * sin(t * f.speed + f.phase) * wander
            let tipLocal = (x: coneX + cos(angle) * length, y: coneY + sin(angle) * length)
            let midLocal = (x: coneX + cos(angle) * length / 2 - sin(angle) * bend, y: coneY + sin(angle) * length / 2 + cos(angle) * bend)
            let tip = pt(tipLocal.x, tipLocal.y)
            tips.append(pt(coneX + cos(angle) * length * 0.5, coneY + sin(angle) * length * 0.5))
            var filo = Path()
            filo.move(to: cone)
            filo.addQuadCurve(to: tip, control: pt(midLocal.x, midLocal.y))
            context.stroke(filo, with: ink, style: StrokeStyle(lineWidth: 1.15 * k, lineCap: .round))
        }

        // 5. La membrana entre los filopodios (lamelipodio) y el cuerpo del cono.
        var web = Path()
        web.move(to: cone)
        web.addLines(tips)
        web.closeSubpath()
        context.fill(web, with: .color(Palette.ink.opacity(0.28)))
        let rx = (5 + 0.5 * sin(t * 1.1 + seed) * wander) * k, ry = 3.8 * k
        context.fill(Path(ellipseIn: CGRect(x: cone.x - rx, y: cone.y - ry, width: rx * 2, height: ry * 2)), with: ink)
    }
}

#Preview("Conos de crecimiento") {
    VStack(spacing: 32) {
        GrowthConeSynapse(approach: 0.1, grip: 0, starOpacity: 0, live: true)
        GrowthConeSynapse(approach: 0.7, grip: 0, starOpacity: 0, live: true)
        GrowthConeSynapse(approach: 1, grip: 1)
    }
    .padding()
    .background(Palette.bg)
}

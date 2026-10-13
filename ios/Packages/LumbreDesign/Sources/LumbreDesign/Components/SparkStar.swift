import SwiftUI

/// Estrella de cuatro puntas: representa la chispa y solo se usa para eso.
/// Mismo trazo que el SVG del sistema de diseño (`M12 1 Q12 12 23 12 Q12 12 12 23 Q12 12 1 12 Q12 12 12 1Z`).
public struct SparkStar: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + (x - 1) / 22 * side, y: origin.y + (y - 1) / 22 * side)
        }
        let center = point(12, 12)
        var path = Path()
        path.move(to: point(12, 1))
        path.addQuadCurve(to: point(23, 12), control: center)
        path.addQuadCurve(to: point(12, 23), control: center)
        path.addQuadCurve(to: point(1, 12), control: center)
        path.addQuadCurve(to: point(12, 1), control: center)
        path.closeSubpath()
        return path
    }
}

#Preview {
    SparkStar()
        .fill(Palette.spark)
        .frame(width: 64, height: 64)
        .lumbreShadow(.glowSpark)
        .padding()
        .background(Palette.bg)
}

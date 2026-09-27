import SwiftUI

public struct ShadowLayer: Sendable {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat
}

private struct TokenShadow: ViewModifier {
    let token: ShadowToken
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        token.layers(for: colorScheme).reduce(AnyView(content)) { view, layer in
            AnyView(view.shadow(color: layer.color, radius: layer.radius, x: layer.x, y: layer.y))
        }
    }
}

public extension View {
    /// Aplica una sombra del sistema. `glowSpark` es solo para la chispa y el CTA del reveal.
    func lumbreShadow(_ token: ShadowToken) -> some View {
        modifier(TokenShadow(token: token))
    }
}

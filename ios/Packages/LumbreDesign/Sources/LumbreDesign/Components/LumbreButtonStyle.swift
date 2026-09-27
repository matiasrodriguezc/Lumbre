import SwiftUI

/// Botón en cuatro variantes. `primary` va una sola vez por pantalla; `pro` solo para compras y funciones Pro.
public struct LumbreButtonStyle: ButtonStyle {
    public enum Variant: Sendable {
        case primary
        case secondary
        case ghost
        case pro
    }

    let variant: Variant
    let fullWidth: Bool
    @Environment(\.isEnabled) private var isEnabled

    public init(_ variant: Variant, fullWidth: Bool = false) {
        self.variant = variant
        self.fullWidth = fullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, variant == .ghost ? Space.s2 : Space.s5)
            .padding(.vertical, Space.s3)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 48)
            .background {
                let shape = RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                switch variant {
                case .primary: shape.fill(Palette.accent)
                case .pro: shape.fill(Palette.pro)
                case .secondary: shape.strokeBorder(Palette.borderStrong, lineWidth: 1)
                case .ghost: Color.clear
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch variant {
        case .primary: return Palette.onAccent
        case .pro: return Palette.onPro
        case .secondary: return Palette.ink
        case .ghost: return Palette.accentText
        }
    }
}

public extension ButtonStyle where Self == LumbreButtonStyle {
    static func lumbre(_ variant: LumbreButtonStyle.Variant, fullWidth: Bool = false) -> LumbreButtonStyle {
        LumbreButtonStyle(variant, fullWidth: fullWidth)
    }
}

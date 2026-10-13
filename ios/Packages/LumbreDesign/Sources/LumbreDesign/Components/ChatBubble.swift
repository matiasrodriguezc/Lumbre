import SwiftUI

/// Burbuja del planificador Pro. El usuario va a la derecha sobre `surface-alt`;
/// el planificador a la izquierda sobre `surface`, identificado en `pro-text`.
public struct ChatBubble: View {
    public enum Role: Sendable {
        case user
        case planner
    }

    let role: Role
    let text: String
    let isStreaming: Bool

    /// - Parameters:
    ///   - text: Markdown liviano (negrita, cursiva, código y links en línea; los saltos de línea se respetan).
    ///   - isStreaming: muestra un cursor mientras la respuesta todavía llega.
    public init(role: Role, text: String, isStreaming: Bool = false) {
        self.role = role
        self.text = text
        self.isStreaming = isStreaming
    }

    public var body: some View {
        HStack {
            if role == .user { Spacer(minLength: Space.s10) }
            VStack(alignment: .leading, spacing: 2) {
                if role == .planner {
                    Text("Planificador", bundle: .module)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.proText)
                }
                content
                    .font(.body)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, Space.s4)
            .padding(.vertical, Space.s3)
            .background(background)
            .overlay {
                if role == .planner {
                    shape.strokeBorder(Palette.border, lineWidth: 1)
                }
            }
            if role == .planner { Spacer(minLength: Space.s10) }
        }
        .accessibilityElement(children: .combine)
    }

    private var content: Text {
        let markdown = (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible)
        )) ?? AttributedString(text)
        let body = Text(markdown)
        guard isStreaming else { return body }
        return body + Text(" ▍").foregroundStyle(Palette.proText)
    }

    private var shape: UnevenRoundedRectangle {
        let big: CGFloat = 18
        let small: CGFloat = 6
        return role == .user
            ? UnevenRoundedRectangle(topLeadingRadius: big, bottomLeadingRadius: big, bottomTrailingRadius: small, topTrailingRadius: big, style: .continuous)
            : UnevenRoundedRectangle(topLeadingRadius: big, bottomLeadingRadius: small, bottomTrailingRadius: big, topTrailingRadius: big, style: .continuous)
    }

    private var background: some View {
        shape.fill(role == .user ? Palette.surfaceAlt : Palette.surface)
    }
}

#Preview {
    VStack(spacing: Space.s2) {
        ChatBubble(role: .user, text: "¿Cómo arranco con Podcast × ruinas este fin de semana?")
        ChatBubble(role: .planner, text: "Empezá por un **piloto** de 10 minutos en un solo lugar.\n1. Elegir el sitio\n2. Pedir permiso", isStreaming: true)
    }
    .padding()
    .background(Palette.bg)
    .preferredColorScheme(.light)
}

// Generado por ios/scripts/generate_tokens.py desde design/system/tokens.json. No editar a mano.

import SwiftUI

/// Colores de marca y semánticos. Cambian solos entre el tema claro y el oscuro.
public enum Palette {
    /// Marca: azul noche de Sunset Nebula. Fondo del modo oscuro, tinta del modo claro y fondo del ícono de app. Fijo en ambos temas.
    public static let night = Color("night", bundle: .module)
    /// Marca: azul señal. Relleno de estados informativos y del dominio 'Tecnología'; texto blanco encima (4.86:1). Como texto usá info-text.
    public static let signalBlue = Color("signal-blue", bundle: .module)
    /// Marca: violeta nebulosa. Reservado a Pro: badge, plan anual destacado, burbuja del planificador. Texto blanco encima (6.98:1). Como texto usá pro-text.
    public static let nebulaViolet = Color("nebula-violet", bundle: .module)
    /// Marca: magenta chispa. SOLO para el momento chispa: CTA principal, la chispa del día, el contador y el foco. Nunca como fondo de pantalla. Texto encima siempre on-accent.
    public static let spark = Color("spark", bundle: .module)
    /// Marca: crema. Fondo del modo claro y tinta del modo oscuro. Fijo en ambos temas.
    public static let cream = Color("cream", bundle: .module)
    /// Fondo de pantalla (window/scaffold).
    public static let bg = Color("bg", bundle: .module)
    /// Tarjetas, listas agrupadas, sheets y barras sobre bg.
    public static let surface = Color("surface", bundle: .module)
    /// Inputs, segmented controls, chips inactivos y tarjetas anidadas dentro de surface.
    public static let surfaceAlt = Color("surface-alt", bundle: .module)
    /// Texto principal e íconos sobre bg, surface y surface-alt (≥12.8:1 en ambos temas).
    public static let ink = Color("ink", bundle: .module)
    /// Texto secundario, metadatos, placeholders y fuentes de un concepto sobre bg, surface y surface-alt (≥6:1).
    public static let inkMuted = Color("ink-muted", bundle: .module)
    /// Divisores y contornos decorativos de tarjetas. No lleva significado: para controles usá border-strong.
    public static let border = Color("border", bundle: .module)
    /// Borde de inputs, botón secundario, checkbox y chips seleccionables (≥3:1 sobre bg, surface y surface-alt).
    public static let borderStrong = Color("border-strong", bundle: .module)
    /// Relleno del CTA principal, la chispa revelada y el indicador de selección. Mismo magenta en ambos temas (3:1 contra bg claro como forma).
    public static let accent = Color("accent", bundle: .module)
    /// Texto e íconos sobre accent (5.52:1). Nunca blanco sobre magenta: da 3.24:1.
    public static let onAccent = Color("on-accent", bundle: .module)
    /// Magenta como TEXTO o ícono chico: links de acción, 'Chispa disponible', estado activo del tab. ≥4.7:1 sobre bg, surface y accent-soft.
    public static let accentText = Color("accent-text", bundle: .module)
    /// Fondo de selección: perfil elegido en onboarding, chip activo, concepto marcado. Texto ink o accent-text encima.
    public static let accentSoft = Color("accent-soft", bundle: .module)
    /// Relleno de elementos Pro (badge, borde del plan destacado, burbuja del planificador).
    public static let pro = Color("pro", bundle: .module)
    /// Texto sobre pro (6.98:1).
    public static let onPro = Color("on-pro", bundle: .module)
    /// Violeta como texto: 'Pro', límites de plan, etiquetas del planificador. ≥5.1:1 sobre bg y surface.
    public static let proText = Color("pro-text", bundle: .module)
    /// Links neutros y estados informativos como texto (≥4.9:1 sobre bg y surface).
    public static let infoText = Color("info-text", bundle: .module)
    /// Texto/ícono de éxito ('Concepto guardado'). Siempre con ícono y palabra: no se distingue de danger solo por tono.
    public static let success = Color("success", bundle: .module)
    /// Texto/ícono de aviso ('Te queda 1 chispa extra hoy').
    public static let warning = Color("warning", bundle: .module)
    /// Texto/ícono de error y acciones destructivas ('Borrar cuenta'). Siempre con ícono y palabra.
    public static let danger = Color("danger", bundle: .module)
    /// Anillo de foco de 2px para teclado/Switch Control/TalkBack (≥4.2:1 sobre todas las superficies).
    public static let focusRing = Color("focus-ring", bundle: .module)
    /// Velo detrás de sheets, paywall y el reveal de la chispa.
    public static let scrim = Color("scrim", bundle: .module)
}

/// Nombres de los colores en el catálogo, para UIKit.
public enum PaletteName {
    public static let night = "night"
    public static let signalBlue = "signal-blue"
    public static let nebulaViolet = "nebula-violet"
    public static let spark = "spark"
    public static let cream = "cream"
    public static let bg = "bg"
    public static let surface = "surface"
    public static let surfaceAlt = "surface-alt"
    public static let ink = "ink"
    public static let inkMuted = "ink-muted"
    public static let border = "border"
    public static let borderStrong = "border-strong"
    public static let accent = "accent"
    public static let onAccent = "on-accent"
    public static let accentText = "accent-text"
    public static let accentSoft = "accent-soft"
    public static let pro = "pro"
    public static let onPro = "on-pro"
    public static let proText = "pro-text"
    public static let infoText = "info-text"
    public static let success = "success"
    public static let warning = "warning"
    public static let danger = "danger"
    public static let focusRing = "focus-ring"
    public static let scrim = "scrim"
}

/// Grilla de 4 pt.
public enum Space {
    public static let s1: CGFloat = 4
    public static let s2: CGFloat = 8
    public static let s3: CGFloat = 12
    public static let s4: CGFloat = 16
    public static let s5: CGFloat = 20
    public static let s6: CGFloat = 24
    public static let s8: CGFloat = 32
    public static let s10: CGFloat = 40
}

public enum Radius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 14
    public static let lg: CGFloat = 24
    public static let full: CGFloat = 999
}

public enum ShadowToken: Sendable {
    case glowSpark
    case elevCard

    public func layers(for scheme: ColorScheme) -> [ShadowLayer] {
        switch (self, scheme) {
        case (.glowSpark, .dark): return [ShadowLayer(color: Color(.sRGB, red: 1.000, green: 0.243, blue: 0.647, opacity: 0.45), radius: 16, x: 0, y: 0)]
        case (.glowSpark, .light): return [ShadowLayer(color: Color(.sRGB, red: 0.761, green: 0.063, blue: 0.435, opacity: 0.22), radius: 12, x: 0, y: 8)]
        case (.elevCard, .dark): return []
        case (.elevCard, .light): return [ShadowLayer(color: Color(.sRGB, red: 0.039, green: 0.086, blue: 0.200, opacity: 0.06), radius: 1, x: 0, y: 1), ShadowLayer(color: Color(.sRGB, red: 0.039, green: 0.086, blue: 0.200, opacity: 0.06), radius: 8, x: 0, y: 4)]
        default: return []
        }
    }
}

/// Estilos de marca en Fraunces. Solo para 20 pt o más.
public enum DisplayStyle: CaseIterable, Sendable {
    case sparkHero
    case counter
    case title1
    case title2

    public var size: CGFloat {
        switch self {
        case .sparkHero: return 34
        case .counter: return 44
        case .title1: return 28
        case .title2: return 22
        }
    }

    public var lineHeight: CGFloat {
        switch self {
        case .sparkHero: return 38
        case .counter: return 44
        case .title1: return 34
        case .title2: return 28
        }
    }

    public var weight: CGFloat {
        switch self {
        case .sparkHero: return 600
        case .counter: return 600
        case .title1: return 600
        case .title2: return 600
        }
    }
}

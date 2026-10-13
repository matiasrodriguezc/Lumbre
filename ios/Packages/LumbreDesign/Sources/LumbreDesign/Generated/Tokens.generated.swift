// Generado por ios/scripts/generate_tokens.py desde design/system/tokens.json. No editar a mano.

import SwiftUI

/// Colores de marca y semánticos. Cambian solos entre el tema claro y el oscuro.
public enum Palette {
    /// Marca: negro neurona. El símbolo, la tinta del tema gris y el relleno del botón principal. Fijo en ambos temas.
    public static let neuron = Color("neuron", bundle: .module)
    /// Marca: gris. Fondo del tema de marca (default) y del ícono de app. Fijo en ambos temas.
    public static let gray = Color("gray", bundle: .module)
    /// Marca: grafito. Fondo del modo oscuro. Fijo en ambos temas.
    public static let graphite = Color("graphite", bundle: .module)
    /// Marca: hueso. La neurona y la tinta en el modo oscuro. Fijo en ambos temas.
    public static let bone = Color("bone", bundle: .module)
    /// Marca: rosa chispa. El único color. Siempre apoyado en negro (o en la neurona): el núcleo, el punto del botón principal, la chispa en la sinapsis. Sobre gris no alcanza contraste (2,5:1): nunca como texto ni relleno grande sobre bg.
    public static let spark = Color("spark", bundle: .module)
    /// Fondo de pantalla (window/scaffold).
    public static let bg = Color("bg", bundle: .module)
    /// Superficies apenas elevadas: sheets, barras y la tarjeta de neurona.
    public static let surface = Color("surface", bundle: .module)
    /// Inputs, campos de búsqueda, chips inactivos y neuronas dormidas de las ilustraciones.
    public static let surfaceAlt = Color("surface-alt", bundle: .module)
    /// Texto principal, íconos y neuronas encendidas (≥9:1 en ambos temas).
    public static let ink = Color("ink", bundle: .module)
    /// Texto secundario y metadatos (≥4.4:1 en todas las superficies).
    public static let inkMuted = Color("ink-muted", bundle: .module)
    /// Separadores, el eje de las listas y las conexiones de la red de fondo. Decorativo.
    public static let border = Color("border", bundle: .module)
    /// Borde de controles (≥3:1).
    public static let borderStrong = Color("border-strong", bundle: .module)
    /// Relleno de la acción principal: negro en el tema gris, hueso en el grafito. Lleva el punto spark adentro.
    public static let accent = Color("accent", bundle: .module)
    /// Texto e íconos sobre accent.
    public static let onAccent = Color("on-accent", bundle: .module)
    /// Rosa como texto chico cuando hace falta (links de la chispa). 5.3:1 sobre bg.
    public static let accentText = Color("accent-text", bundle: .module)
    /// Fondo de selección. El elegido de verdad va en accent (negro) con on-accent.
    public static let accentSoft = Color("accent-soft", bundle: .module)
    /// Pro: negro con la palabra Pro. Ya no hay un color propio.
    public static let pro = Color("pro", bundle: .module)
    /// Texto sobre pro.
    public static let onPro = Color("on-pro", bundle: .module)
    /// Texto de cosas Pro: siempre junto a la palabra Pro o un ícono.
    public static let proText = Color("pro-text", bundle: .module)
    /// Información neutra y links secundarios (subrayados).
    public static let infoText = Color("info-text", bundle: .module)
    /// Éxito, siempre con ícono y palabra.
    public static let success = Color("success", bundle: .module)
    /// Advertencia, siempre con ícono y palabra.
    public static let warning = Color("warning", bundle: .module)
    /// Error y acciones destructivas, siempre con ícono y palabra.
    public static let danger = Color("danger", bundle: .module)
    /// Anillo de foco de 2px, separado 2px del control.
    public static let focusRing = Color("focus-ring", bundle: .module)
    /// Velo detrás de sheets y diálogos.
    public static let scrim = Color("scrim", bundle: .module)
}

/// Nombres de los colores en el catálogo, para UIKit.
public enum PaletteName {
    public static let neuron = "neuron"
    public static let gray = "gray"
    public static let graphite = "graphite"
    public static let bone = "bone"
    public static let spark = "spark"
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
        case (.glowSpark, .dark): return [ShadowLayer(color: Color(.sRGB, red: 1.000, green: 0.243, blue: 0.647, opacity: 0.30), radius: 14, x: 0, y: 0)]
        case (.glowSpark, .light): return [ShadowLayer(color: Color(.sRGB, red: 0.055, green: 0.055, blue: 0.063, opacity: 0.16), radius: 12, x: 0, y: 8)]
        case (.elevCard, .dark): return []
        case (.elevCard, .light): return [ShadowLayer(color: Color(.sRGB, red: 0.055, green: 0.055, blue: 0.063, opacity: 0.06), radius: 1, x: 0, y: 1), ShadowLayer(color: Color(.sRGB, red: 0.055, green: 0.055, blue: 0.063, opacity: 0.06), radius: 8, x: 0, y: 4)]
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

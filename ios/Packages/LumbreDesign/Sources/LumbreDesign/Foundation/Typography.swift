import CoreText
import SwiftUI
import UIKit

extension DisplayStyle {
    /// Estilo del sistema con el que escala en Dynamic Type.
    var textStyle: UIFont.TextStyle {
        switch self {
        case .sparkHero, .counter: return .largeTitle
        case .title1: return .title1
        case .title2: return .title2
        }
    }

    /// El eje WONK en 1 queda reservado al título de la chispa (y al wordmark).
    var wonk: Bool { self == .sparkHero }
}

/// Fraunces variable con SOFT 100. Si el archivo no está en el paquete, se usa la serif del sistema (New York).
public enum LumbreFont {
    private static func tag(_ code: String) -> NSNumber {
        NSNumber(value: code.utf8.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) })
    }

    private nonisolated(unsafe) static let frauncesDescriptor: CTFontDescriptor? = {
        guard
            let url = Bundle.module.url(forResource: "Fraunces", withExtension: "ttf"),
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor]
        else { return nil }
        return descriptors.first
    }()

    /// Indica si Fraunces está empaquetada. Sin ella, los estilos display usan New York.
    public static var hasFraunces: Bool { frauncesDescriptor != nil }

    /// Fuente display a un tamaño ya escalado.
    public static func uiDisplay(_ style: DisplayStyle, size: CGFloat) -> UIFont {
        guard let base = frauncesDescriptor else {
            let system = UIFont.systemFont(ofSize: size, weight: .semibold)
            let serif = system.fontDescriptor.withDesign(.serif) ?? system.fontDescriptor
            let numbers = serif.addingAttributes([
                .featureSettings: [[
                    UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                    UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector,
                ]],
            ])
            return UIFont(descriptor: numbers, size: size)
        }
        let variation: [NSNumber: NSNumber] = [
            tag("wght"): NSNumber(value: Double(style.weight)),
            tag("SOFT"): 100,
            tag("WONK"): style.wonk ? 1 : 0,
            tag("opsz"): NSNumber(value: Double(min(max(size, 9), 144))),
        ]
        let features: [[CFString: Any]] = [
            [kCTFontFeatureTypeIdentifierKey: kNumberSpacingType, kCTFontFeatureSelectorIdentifierKey: kMonospacedNumbersSelector],
            [kCTFontFeatureTypeIdentifierKey: kNumberCaseType, kCTFontFeatureSelectorIdentifierKey: kUpperCaseNumbersSelector],
        ]
        let attributes = [kCTFontVariationAttribute: variation, kCTFontFeatureSettingsAttribute: features] as CFDictionary
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(base, attributes)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil) as UIFont
    }

    /// Fuente display escalada según el tamaño de texto dado.
    public static func uiDisplay(_ style: DisplayStyle, dynamicTypeSize: DynamicTypeSize = .large) -> UIFont {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let size = UIFontMetrics(forTextStyle: style.textStyle).scaledValue(for: style.size, compatibleWith: traits)
        return uiDisplay(style, size: size)
    }
}

private struct DisplayFont: ViewModifier {
    let style: DisplayStyle
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content.font(Font(LumbreFont.uiDisplay(style, dynamicTypeSize: dynamicTypeSize) as CTFont))
    }
}

public extension View {
    /// Tipografía de marca (Fraunces). Nunca en botones, chips, listas ni texto corrido.
    func lumbreDisplay(_ style: DisplayStyle) -> some View {
        modifier(DisplayFont(style: style))
    }
}

import SwiftUI
import UIKit

public enum LumbreAppearance {
    /// Configura lo que SwiftUI no expone: el large title en Fraunces. Llamar una vez al arrancar la app.
    @MainActor
    public static func configure() {
        let ink = UIColor(named: PaletteName.ink, in: .module, compatibleWith: nil) ?? .label
        let largeTitle = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: LumbreFont.uiDisplay(.title1, size: DisplayStyle.title1.size))
        let navigationBar = UINavigationBar.appearance()
        navigationBar.largeTitleTextAttributes = [.font: largeTitle, .foregroundColor: ink]
        navigationBar.titleTextAttributes = [.foregroundColor: ink]
    }
}

/// Tema elegido en Perfil. El oscuro es el de marca y el default.
public enum ThemePreference: String, CaseIterable, Identifiable, Sendable {
    case dark
    case light
    case system

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

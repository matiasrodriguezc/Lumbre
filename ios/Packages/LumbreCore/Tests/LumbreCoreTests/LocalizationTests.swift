import Foundation
import Testing
@testable import LumbreCore

@Suite struct LocalizationTests {
    static let errors: [LumbreAPIError] = [
        .quotaExceeded, .tooManyCategories, .invalidThesis, .invalidCategory, .invalidSource, .needsThesis,
        .proRequired, .notEnoughConcepts, .tooManyProjects, .accountRequired, .invalidEmail, .invalidCode,
        .emailInUse, .offline, .unexpected,
    ]

    /// Los errores salen del catálogo de LumbreCore (`bundle: .module`), que viaja en la app y en cada extensión:
    /// así el widget, los App Intents y la Share Extension los muestran en inglés aunque no tengan la tabla de la app.
    @Test func apiErrorsAreInTheCatalogWithEnglish() throws {
        let path = try #require(Bundle.module.path(forResource: "en", ofType: "lproj"))
        let english = try #require(NSDictionary(contentsOfFile: path + "/Localizable.strings") as? [String: String])
        for error in Self.errors {
            let message = try #require(error.errorDescription)
            // En el idioma del simulador: la clave (es) o su traducción (en), pero siempre del catálogo.
            #expect(english.keys.contains(message) || english.values.contains(message), "\(error)")
        }
    }
}

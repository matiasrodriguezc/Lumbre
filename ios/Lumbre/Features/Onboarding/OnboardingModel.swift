import Foundation
import LumbreCore
import Observation

/// Pasos del onboarding, en orden. El `rawValue` es el `step` de `onboarding_step_completed`.
enum OnboardingStep: String, CaseIterable, Hashable {
    case welcome, profile, seeds
    case sparkHour = "spark_hour"
    case push

    /// 1 a 5.
    var index: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
    /// Nombre de pantalla de `docs/analytics.md` §6.
    var screenName: String { "onboarding_\(rawValue)" }
}

/// Una idea semilla del onboarding.
struct SeedIdea: Identifiable, Equatable {
    let id = UUID()
    var text = ""
    var category = ""
    /// El usuario tocó la categoría: ya no se reemplaza al cambiar de perfil.
    var categoryEdited = false
    /// Ya se guardó en la bóveda (no se vuelve a mandar si vuelve atrás).
    var isSaved = false

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedCategory: String { category.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isFilled: Bool { !trimmedText.isEmpty }
}

/// Estado del onboarding: lo que elige la persona antes de que se guarde el perfil.
@MainActor
@Observable
final class OnboardingModel {
    static let seedCount = 3

    var path: [OnboardingStep] = []
    var profiles: [CreativeProfile] {
        didSet { refreshSuggestedCategories() }
    }
    var seeds: [SeedIdea]
    /// Rol propio (opcional), en sus palabras.
    var role: String
    var trimmedRole: String { role.trimmingCharacters(in: .whitespacesAndNewlines) }
    var sparkTime: Date
    private(set) var isSavingSeeds = false
    private(set) var isFinishing = false
    private let startedAt = Date.now
    private var didTrackStart = false

    init(profile: Profile?) {
        let existing = profile?.creativeProfiles ?? []
        profiles = existing
        role = profile?.creativeRole ?? ""
        seeds = (0..<Self.seedCount).map { _ in SeedIdea() }
        let time = profile?.sparkTime ?? .default
        sparkTime = Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: .now) ?? .now
        refreshSuggestedCategories()
    }

    // MARK: Pasos

    func trackStartIfNeeded() {
        guard !didTrackStart else { return }
        didTrackStart = true
        Analytics.track(.onboardingStarted)
    }

    /// Registra el paso terminado y pasa al siguiente.
    func complete(_ step: OnboardingStep) {
        Analytics.track(.onboardingStepCompleted(step: step.rawValue, index: step.index))
        let all = OnboardingStep.allCases
        guard let position = all.firstIndex(of: step), position + 1 < all.count else { return }
        path.append(all[position + 1])
    }

    // MARK: Semillas

    /// Categorías sugeridas según los perfiles elegidos, más algunas de otros mundos para que haya choque.
    var suggestedCategories: [String] {
        var result = profiles.flatMap(\.suggestedCategories)
        if result.isEmpty { result = CreativeProfile.curiosity.suggestedCategories }
        for extra in Self.otherWorlds where !result.contains(extra) {
            result.append(extra)
        }
        return result
    }

    static let otherWorlds = [
        String(localized: "Naturaleza"), String(localized: "Urbanismo"), String(localized: "Psicología"), String(localized: "Música"),
    ]

    /// Una categoría distinta por semilla: perfil 1, perfil 2 y algo de otro mundo.
    private var defaultCategories: [String] {
        let fromProfiles = profiles.flatMap(\.suggestedCategories)
        let first = fromProfiles.first ?? CreativeProfile.curiosity.suggestedCategories[0]
        let second = profiles.count > 1 ? profiles[1].suggestedCategories[0] : (fromProfiles.dropFirst().first ?? CreativeProfile.curiosity.suggestedCategories[1])
        return [first, second, Self.otherWorlds[0]]
    }

    private func refreshSuggestedCategories() {
        let defaults = defaultCategories
        for index in seeds.indices where !seeds[index].categoryEdited && !seeds[index].isSaved {
            seeds[index].category = defaults[index % defaults.count]
        }
    }

    func setCategory(_ name: String, forSeedAt index: Int) {
        seeds[index].category = name
        seeds[index].categoryEdited = true
    }

    /// Ejemplo para quien no sabe qué poner, según la categoría sugerida.
    func placeholder(forSeedAt index: Int) -> String {
        Self.examples[seeds[index].trimmedCategory] ?? String(localized: "Algo que leíste, viste o pensaste")
    }

    private static let examples: [String: String] = [
        String(localized: "Software"): String(localized: "Ej.: Los PR chicos se revisan más rápido y con menos errores"),
        String(localized: "Producto"): String(localized: "Ej.: La gente usa lo que ve primero, no lo que es mejor"),
        String(localized: "Escritura"): String(localized: "Ej.: Un buen gancho deja una pregunta abierta"),
        String(localized: "Narrativa"): String(localized: "Ej.: Un personaje se define por lo que elige perder"),
        String(localized: "Negocios"): String(localized: "Ej.: Cobrar por suscripción cambia quién te elige"),
        String(localized: "Marketing"): String(localized: "Ej.: Limitar la oferta sube el valor percibido"),
        String(localized: "Diseño"): String(localized: "Ej.: Lo que se ve primero es lo que parece importar"),
        String(localized: "Interfaces"): String(localized: "Ej.: Un buen default ahorra mil ajustes"),
        String(localized: "Ciencia"): String(localized: "Ej.: Los sistemas complejos se autoorganizan sin un jefe"),
        String(localized: "Historia"): String(localized: "Ej.: Las rutas comerciales movían ideas, no solo cosas"),
        String(localized: "Naturaleza"): String(localized: "Ej.: Las hormigas encuentran el camino más corto dejando rastros"),
    ]

    var filledSeedCount: Int { seeds.filter(\.isFilled).count }
    var savedSeedCount: Int { seeds.filter(\.isSaved).count }

    /// Guarda en la bóveda las semillas escritas que todavía no se guardaron.
    func saveSeeds(api: any LumbreAPI) async throws {
        isSavingSeeds = true
        defer { isSavingSeeds = false }
        let fallback = defaultCategories
        for index in seeds.indices where seeds[index].isFilled && !seeds[index].isSaved {
            let seed = seeds[index]
            let category = seed.trimmedCategory.isEmpty ? fallback[index % fallback.count] : seed.trimmedCategory
            _ = try await api.capture(CaptureRequest(thesis: seed.trimmedText, category: category, source: .text))
            seeds[index].isSaved = true
            Analytics.track(.seedIdeaAdded(index: index + 1, input: "text"))
        }
    }

    // MARK: Hora

    var selectedSparkTime: SparkTime {
        let components = Calendar.current.dateComponents([.hour, .minute], from: sparkTime)
        return SparkTime(hour: components.hour ?? 8, minute: components.minute ?? 0)
    }

    func trackSparkHour() {
        let time = selectedSparkTime
        Analytics.track(.sparkHourSet(hour: time.hour, isDefault: time == .default, context: "onboarding"))
    }

    // MARK: Fin

    /// Guarda el perfil y marca el onboarding como terminado.
    func finish(api: any LumbreAPI) async throws -> Profile {
        isFinishing = true
        defer { isFinishing = false }
        let language = Locale.current.language.languageCode?.identifier == "en" ? "en" : "es"
        let profile = try await api.updateProfile(ProfileUpdate(
            creativeProfiles: profiles,
            sparkTime: selectedSparkTime,
            timezone: TimeZone.current.identifier,
            locale: language,
            completeOnboarding: true,
            creativeRole: trimmedRole
        ))
        Analytics.track(.onboardingStepCompleted(step: OnboardingStep.push.rawValue, index: OnboardingStep.push.index))
        Analytics.track(.onboardingCompleted(
            durationSeconds: Int(Date.now.timeIntervalSince(startedAt)),
            profilesCount: profiles.count,
            seedsCount: savedSeedCount
        ))
        return profile
    }
}

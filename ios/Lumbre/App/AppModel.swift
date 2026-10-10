import LumbreCore
import Observation
import SwiftUI

enum AppTab: Hashable {
    case today, vault, projects, profile
    /// No es un destino: abre la sheet de Capturar.
    case capture
}

/// Lo que abre un link profundo, una push, el widget o un App Intent.
enum AppRoute: Hashable {
    case today
    case spark(Spark.ID)
    case concept(Concept.ID)
    case capture(entry: String)
    case paywall(trigger: String)
}

/// Estado global de la app: sesión, perfil, navegación y paywall.
/// `LumbreApp` lo crea y lo inyecta con `.environment(appModel)`; las pantallas lo leen con `@Environment(AppModel.self)`.
@MainActor
@Observable
final class AppModel {
    /// nil mientras carga el primer perfil.
    private(set) var profile: Profile?
    private(set) var profileError: Error?

    var selectedTab: AppTab = .today
    /// Ruta pendiente: la pantalla correspondiente la consume y la vuelve a nil.
    var pendingRoute: AppRoute?

    /// Paywall abierto, con el `trigger` de `paywall_shown` (`planner`, `distill`, `extra_sparks`, `settings`…).
    var paywallTrigger: String?
    /// Sheet de Capturar abierta, con el `entry` de `capture_opened`.
    var captureEntry: String?

    /// Cambia cada vez que se guarda algo, para que las pantallas vuelvan a cargar.
    private(set) var dataVersion = 0

    var isPro: Bool { profile?.isPro ?? false }
    var isGuest: Bool { profile?.isGuest ?? true }
    var needsOnboarding: Bool { profile.map { !$0.isOnboarded } ?? false }

    func loadProfile(api: any LumbreAPI) async {
        do {
            profile = try await api.profile()
            profileError = nil
        } catch {
            profileError = error
        }
    }

    func setProfile(_ profile: Profile) {
        self.profile = profile
    }

    /// Avisa a las pantallas que hay datos nuevos.
    func dataChanged() {
        dataVersion += 1
    }

    func presentPaywall(trigger: String) {
        paywallTrigger = trigger
    }

    func presentCapture(entry: String = "fab") {
        captureEntry = entry
    }

    func open(_ route: AppRoute) {
        switch route {
        case .today, .spark:
            selectedTab = .today
            pendingRoute = route
        case .concept:
            selectedTab = .vault
            pendingRoute = route
        case .capture(let entry):
            presentCapture(entry: entry)
        case .paywall(let trigger):
            presentPaywall(trigger: trigger)
        }
    }

    /// Después de cerrar sesión o borrar la cuenta: vuelve al onboarding.
    func reset() {
        profile = nil
        selectedTab = .today
        pendingRoute = nil
        dataVersion += 1
    }
}

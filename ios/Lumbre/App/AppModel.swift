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
    /// `entry` llega hasta `spark_revealed`: `app`, `push` o `widget`.
    case spark(Spark.ID, entry: String = "app")
    /// El planificador de una chispa, apilado sobre su detalle.
    case planner(Spark.ID)
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
    /// Sheet de crear cuenta abierta, con el `trigger` de `account_prompt_shown` (`extra_sparks`, `planner`…).
    var accountTrigger: String?
    /// Sheet "Tus ideas y la IA" abierta (cuando algo que usa IA no tiene permiso).
    var isAskingAIConsent = false
    /// Hoja de importar notas abierta (flag `import_notes`): vacía o con las notas que mandó el atajo.
    var importRequest: ImportRequest?

    /// Cambia cada vez que se guarda algo, para que las pantallas vuelvan a cargar.
    private(set) var dataVersion = 0
    /// Cambia al cerrar sesión o borrar la cuenta: `RootView` vuelve a cargar el perfil desde cero.
    private(set) var sessionVersion = 0
    /// Solo Debug ("Volver a ver el onboarding"): muestra el onboarding aunque el perfil ya lo haya terminado.
    private(set) var isReplayingOnboarding = false

    var isPro: Bool { profile?.isPro ?? false }
    var isGuest: Bool { profile?.isGuest ?? true }
    var needsOnboarding: Bool {
        guard let profile else { return false }
        return !profile.isOnboarded || isReplayingOnboarding
    }

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

    /// Último paso del onboarding: guarda el perfil y cae en Hoy.
    func completeOnboarding(with profile: Profile) {
        self.profile = profile
        isReplayingOnboarding = false
        selectedTab = .today
        dataVersion += 1
    }

    /// Solo Debug: vuelve a mostrar el onboarding sin borrar nada.
    func replayOnboarding() {
        isReplayingOnboarding = true
    }

    /// Avisa a las pantallas que hay datos nuevos.
    func dataChanged() {
        dataVersion += 1
    }

    /// Abre el paywall. Con el flag `paywall` apagado no se muestra.
    func presentPaywall(trigger: String) {
        guard FeatureFlag.paywall.isEnabled else { return }
        paywallTrigger = trigger
    }

    /// Le pide la cuenta a un invitado (por ejemplo, cuando el servidor responde `account_required`).
    func presentAccount(trigger: String) {
        guard isGuest else { return }
        Analytics.track(.accountPromptShown(trigger: trigger))
        accountTrigger = trigger
    }

    /// Vuelve a mostrar el pedido de consentimiento para IA.
    func presentAIConsent() {
        isAskingAIConsent = true
    }

    /// Después de crear la cuenta o entrar a otra: el perfil nuevo y las pantallas vuelven a cargar.
    /// Si entró a otra cuenta ya configurada, cae en Hoy sin pasar por el onboarding.
    func accountChanged(to profile: Profile, purpose: EmailCodePurpose) {
        self.profile = profile
        profileError = nil
        if purpose == .signIn {
            selectedTab = .today
            pendingRoute = nil
            isReplayingOnboarding = false
        }
        dataVersion += 1
    }

    /// Abre la hoja de importar notas. Con `notes` (las del atajo de Apple Notes) va directo a la vista previa.
    func presentImport(notes: [ImportNote]? = nil, origin: ImportOrigin? = nil) {
        guard FeatureFlag.importNotes.isEnabled else { return }
        importRequest = ImportRequest(notes: notes, origin: origin)
    }

    func presentCapture(entry: String = "fab") {
        captureEntry = entry
    }

    func open(_ route: AppRoute) {
        switch route {
        case .today, .spark, .planner:
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
        profileError = nil
        selectedTab = .today
        pendingRoute = nil
        paywallTrigger = nil
        captureEntry = nil
        accountTrigger = nil
        isAskingAIConsent = false
        importRequest = nil
        // Las huellas de lo importado son de esta cuenta.
        ImportHistory().clear()
        isReplayingOnboarding = false
        dataVersion += 1
        sessionVersion += 1
    }
}

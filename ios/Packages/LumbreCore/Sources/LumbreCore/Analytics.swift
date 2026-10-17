import Foundation
import os

/// Eventos de la app (fuente A de `docs/analytics.md` §5). Los del servidor los emite el backend.
/// Nunca llevan contenido del usuario: solo tipos, rangos, slugs e ids.
public enum AnalyticsEvent: Sendable, Equatable {
    // Onboarding y cuenta
    case onboardingStarted
    case onboardingStepCompleted(step: String, index: Int)
    case seedIdeaAdded(index: Int, input: String)
    case sparkHourSet(hour: Int, isDefault: Bool, context: String)
    case pushPermissionPrompted(context: String)
    case pushPermissionResponded(granted: Bool, systemPromptShown: Bool)
    case guestEntered
    case accountPromptShown(trigger: String)
    /// Entra a una cuenta que ya existía (`account_linked`, cuando un invitado crea la suya, lo manda el servidor).
    case signedIn(method: String)
    case aiConsentResponded(granted: Bool)
    case onboardingCompleted(durationSeconds: Int, profilesCount: Int, seedsCount: Int)
    // Captura
    case captureOpened(entry: String)
    case captureSubmitted(entry: String, sourceType: SourceType, distillRequested: Bool, offline: Bool, words: Int)
    case captureFailed(reason: String)
    case ocrCompleted(kind: String, success: Bool, words: Int)
    case offlineQueueFlushed(count: Int)
    case distillFallbackShown(reason: String)
    case conceptDraftResolved(action: String)
    case conceptCategoryChanged(context: String)
    // Chispa
    case notificationOpened(type: String, minutesAfterSent: Int?)
    case sparkRevealed(mode: SparkMode, isFirst: Bool, entry: String, reduceMotion: Bool)
    case sparkExtraRequested(mode: SparkMode, source: String)
    case sparkEmptyStateShown(reason: String)
    /// `format`: `story` (1080 × 1920) o `feed` (1080 × 1350).
    case shareCardCreated(mode: SparkMode, format: String)
    case sparkShared(activityType: String?)
    case aiContentReported(object: String, reason: ReportReason)
    // Bóveda
    case vaultSearched(words: Int, results: Int)
    case vaultFiltered(domain: String)
    case conceptOpened(entry: String)
    /// Desde una neurona que nació de una chispa, abre la chispa original (flag `spark_neuron`).
    case sparkOriginOpened
    // Planificador, proyectos y export
    case plannerOpened(entry: String)
    case markdownExported(object: String)
    // Pro
    case paywallShown(trigger: String, variant: String)
    case paywallDismissed(trigger: String, variant: String, secondsVisible: Int)
    case purchaseStarted(product: String, trigger: String, variant: String)
    case purchaseRestored(found: Bool)
    // Widget, perfil y privacidad
    case widgetTapped(action: String, size: String)
    case settingsChanged(setting: String)
    case errorShown(screen: String, code: String)

    public var name: String {
        switch self {
        case .onboardingStarted: "onboarding_started"
        case .onboardingStepCompleted: "onboarding_step_completed"
        case .seedIdeaAdded: "seed_idea_added"
        case .sparkHourSet: "spark_hour_set"
        case .pushPermissionPrompted: "push_permission_prompted"
        case .pushPermissionResponded: "push_permission_responded"
        case .guestEntered: "guest_entered"
        case .accountPromptShown: "account_prompt_shown"
        case .signedIn: "signed_in"
        case .aiConsentResponded: "ai_consent_responded"
        case .onboardingCompleted: "onboarding_completed"
        case .captureOpened: "capture_opened"
        case .captureSubmitted: "capture_submitted"
        case .captureFailed: "capture_failed"
        case .ocrCompleted: "ocr_completed"
        case .offlineQueueFlushed: "offline_queue_flushed"
        case .distillFallbackShown: "distill_fallback_shown"
        case .conceptDraftResolved: "concept_draft_resolved"
        case .conceptCategoryChanged: "concept_category_changed"
        case .notificationOpened: "notification_opened"
        case .sparkRevealed: "spark_revealed"
        case .sparkExtraRequested: "spark_extra_requested"
        case .sparkEmptyStateShown: "spark_empty_state_shown"
        case .shareCardCreated: "share_card_created"
        case .sparkShared: "spark_shared"
        case .aiContentReported: "ai_content_reported"
        case .vaultSearched: "vault_searched"
        case .vaultFiltered: "vault_filtered"
        case .conceptOpened: "concept_opened"
        case .sparkOriginOpened: "spark_origin_opened"
        case .plannerOpened: "planner_opened"
        case .markdownExported: "markdown_exported"
        case .paywallShown: "paywall_shown"
        case .paywallDismissed: "paywall_dismissed"
        case .purchaseStarted: "purchase_started"
        case .purchaseRestored: "purchase_restored"
        case .widgetTapped: "widget_tapped"
        case .settingsChanged: "settings_changed"
        case .errorShown: "error_shown"
        }
    }

    /// Propiedades del evento, con los nombres y valores de `docs/analytics.md`.
    public var properties: [String: AnalyticsValue] {
        switch self {
        case .onboardingStarted, .guestEntered, .sparkOriginOpened:
            [:]
        case let .onboardingStepCompleted(step, index):
            ["step": .string(step), "step_index": .int(index)]
        case let .seedIdeaAdded(index, input):
            ["index": .int(index), "input": .string(input)]
        case let .sparkHourSet(hour, isDefault, context):
            ["hour": .int(hour), "is_default": .bool(isDefault), "context": .string(context)]
        case let .pushPermissionPrompted(context):
            ["context": .string(context)]
        case let .pushPermissionResponded(granted, shown):
            ["granted": .bool(granted), "system_prompt_shown": .bool(shown)]
        case let .accountPromptShown(trigger):
            ["trigger": .string(trigger)]
        case let .signedIn(method):
            ["method": .string(method)]
        case let .aiConsentResponded(granted):
            ["granted": .bool(granted)]
        case let .onboardingCompleted(duration, profiles, seeds):
            ["duration_s": .int(duration), "profiles_count": .int(profiles), "seeds_count": .int(seeds)]
        case let .captureOpened(entry):
            ["entry": .string(entry)]
        case let .captureSubmitted(entry, sourceType, distill, offline, words):
            ["entry": .string(entry), "source_type": .string(sourceType.rawValue), "distill_requested": .bool(distill),
             "offline": .bool(offline), "length_bucket": .string(Self.lengthBucket(words))]
        case let .captureFailed(reason):
            ["reason": .string(reason)]
        case let .ocrCompleted(kind, success, words):
            ["kind": .string(kind), "success": .bool(success), "length_bucket": .string(Self.lengthBucket(words))]
        case let .offlineQueueFlushed(count):
            ["count": .int(count)]
        case let .distillFallbackShown(reason):
            ["reason": .string(reason)]
        case let .conceptDraftResolved(action):
            ["action": .string(action)]
        case let .conceptCategoryChanged(context):
            ["context": .string(context)]
        case let .notificationOpened(type, minutes):
            ["type": .string(type), "minutes_after_sent": minutes.map(AnalyticsValue.int) ?? .null]
        case let .sparkRevealed(mode, isFirst, entry, reduceMotion):
            ["mode": .string(mode.rawValue), "is_first": .bool(isFirst), "entry": .string(entry), "reduce_motion": .bool(reduceMotion)]
        case let .sparkExtraRequested(mode, source):
            ["mode": .string(mode.rawValue), "source": .string(source)]
        case let .sparkEmptyStateShown(reason):
            ["reason": .string(reason)]
        case let .shareCardCreated(mode, format):
            ["mode": .string(mode.rawValue), "format": .string(format)]
        case let .sparkShared(activityType):
            ["activity_type": activityType.map(AnalyticsValue.string) ?? .null]
        case let .aiContentReported(object, reason):
            ["object": .string(object), "reason": .string(reason.rawValue)]
        case let .vaultSearched(words, results):
            ["query_length_bucket": .string(words <= 2 ? "1-2" : words <= 5 ? "3-5" : "6+"),
             "results_bucket": .string(results == 0 ? "0" : results <= 5 ? "1-5" : "6+")]
        case let .vaultFiltered(domain):
            ["domain": .string(domain)]
        case let .conceptOpened(entry):
            ["entry": .string(entry)]
        case let .plannerOpened(entry):
            ["entry": .string(entry)]
        case let .markdownExported(object):
            ["object": .string(object)]
        case let .paywallShown(trigger, variant):
            ["trigger": .string(trigger), "variant": .string(variant)]
        case let .paywallDismissed(trigger, variant, seconds):
            ["trigger": .string(trigger), "variant": .string(variant), "seconds_visible": .int(seconds)]
        case let .purchaseStarted(product, trigger, variant):
            ["product": .string(product), "trigger": .string(trigger), "variant": .string(variant)]
        case let .purchaseRestored(found):
            ["found": .bool(found)]
        case let .widgetTapped(action, size):
            ["action": .string(action), "size": .string(size)]
        case let .settingsChanged(setting):
            ["setting": .string(setting)]
        case let .errorShown(screen, code):
            ["screen": .string(screen), "code": .string(code)]
        }
    }

    /// `<30`, `30-199`, `200-999`, `1000+` palabras.
    static func lengthBucket(_ words: Int) -> String {
        switch words {
        case ..<30: "<30"
        case 30..<200: "30-199"
        case 200..<1000: "200-999"
        default: "1000+"
        }
    }
}

public enum AnalyticsValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case null
}

/// Destino de los eventos: PostHog cuando haya clave (paso 44), la consola mientras tanto.
public protocol AnalyticsSink: Sendable {
    func track(_ name: String, properties: [String: AnalyticsValue])
    func screen(_ name: String)
    func identify(userID: String, properties: [String: AnalyticsValue])
    func reset()
}

/// Escribe los eventos en el log del sistema (categoría `analytics`), sin contenido del usuario.
public struct ConsoleAnalyticsSink: AnalyticsSink {
    private let logger = Logger(subsystem: "com.matiasrodriguezc.lumbre", category: "analytics")

    public init() {}

    public func track(_ name: String, properties: [String: AnalyticsValue]) {
        logger.debug("event \(name, privacy: .public) \(String(describing: properties), privacy: .public)")
    }

    public func screen(_ name: String) {
        logger.debug("screen \(name, privacy: .public)")
    }

    public func identify(userID: String, properties: [String: AnalyticsValue]) {
        logger.debug("identify \(userID, privacy: .private)")
    }

    public func reset() {
        logger.debug("reset")
    }
}

/// Punto único para mandar eventos. La app lo configura al arrancar.
public enum Analytics {
    private static let lock = OSAllocatedUnfairLock<any AnalyticsSink>(initialState: ConsoleAnalyticsSink())

    public static func configure(_ sink: any AnalyticsSink) {
        lock.withLock { $0 = sink }
    }

    public static func track(_ event: AnalyticsEvent) {
        let sink = lock.withLock { $0 }
        sink.track(event.name, properties: event.properties)
    }

    /// Nombres de pantalla de `docs/analytics.md` §6.
    public static func screen(_ name: String) {
        let sink = lock.withLock { $0 }
        sink.screen(name)
    }

    public static func identify(userID: UUID, profile: Profile) {
        let sink = lock.withLock { $0 }
        sink.identify(userID: userID.uuidString.lowercased(), properties: [
            "plan": .string(profile.plan == .guest ? "free" : profile.plan.rawValue),
            "is_guest": .bool(profile.isGuest),
            "spark_hour": .string(String(format: "%02d:%02d", profile.sparkTime.hour, profile.sparkTime.minute)),
            "timezone": .string(profile.timezone),
        ])
    }

    public static func reset() {
        let sink = lock.withLock { $0 }
        sink.reset()
    }
}

/// Feature flags (plan.md §11: todo lo nuevo detrás de un flag de PostHog).
/// Mientras no haya PostHog, valen los defaults de acá; en Debug se pueden pisar con `-flag.<nombre> YES|NO`.
public enum FeatureFlag: String, Sendable, CaseIterable {
    case distillation = "distillation"
    case planner = "planner"
    case extraSparks = "extra_sparks"
    case pickMode = "pick_mode"
    case shareCard = "share_card"
    case offlineQueue = "offline_queue"
    case ocr = "ocr"
    case voiceCapture = "voice_capture"
    case projects = "projects"
    case paywall = "paywall"
    /// Identidad neuronal en la app: sinapsis, pulso de carga, ilustraciones y red de fondo.
    case neuralIdentity = "neural_identity"
    /// Planificador con el método de los tres cuartos de Walt Disney (planner.v2).
    case disneyPlanner = "planner_disney"
    /// Crear la cuenta o entrar con un código por email (en vez del aviso de "las cuentas llegan pronto").
    case emailAccount = "account_email"
    /// Share Extension: compartir texto, links, imágenes y PDFs desde otras apps.
    case shareExtension = "share_extension"
    /// Widgets de la chispa de hoy y de captura rápida (y el control de captura).
    case widgets = "widgets"
    /// App Intents y atajos de Siri: guardar una idea y ver la chispa de hoy.
    case appIntents = "app_intents"
    /// Reveal de 900 ms con la coreografía de design/reveal: la sinapsis entra, cruza el impulso y salta la chispa;
    /// cierre con fundido. Apagado, queda el reveal anterior (~1.200 ms).
    case revealSynapse = "reveal_synapse"
    /// La chispa guardada se vuelve neurona (paso 88): `save_spark` con `p_as_neuron`, "Nació de una chispa" en la Red
    /// y el camino a la chispa original. El servidor también lo apaga con `app_config.spark_neuron_enabled`.
    case sparkNeuron = "spark_neuron"
    /// Tarjeta para compartir con las zonas seguras de design/compartir: margen de abajo de 340 y categoría en una línea.
    case shareCardSafeZones = "share_card_safe_zones"
    /// Formato feed (1080 × 1350) como segunda opción en la hoja de compartir; historias sigue siendo el de siempre.
    case shareCardFeed = "share_card_feed"

    public var defaultValue: Bool { true }

    public var isEnabled: Bool {
        // `-flag.<nombre> NO` llega como el texto "NO": `bool(forKey:)` lo entiende, `as? Bool` no.
        if UserDefaults.standard.object(forKey: "flag.\(rawValue)") != nil {
            return UserDefaults.standard.bool(forKey: "flag.\(rawValue)")
        }
        return FeatureFlags.remote(self) ?? FeatureFlags.shared(self) ?? defaultValue
    }
}

public enum FeatureFlags {
    private static let lock = OSAllocatedUnfairLock<[String: Bool]>(initialState: [:])

    /// Valores que llegan de PostHog (paso 44). Quedan también en el App Group para las extensiones.
    public static func update(_ values: [String: Bool]) {
        lock.withLock { $0 = values }
        LumbreShared.flags = values
    }

    static func remote(_ flag: FeatureFlag) -> Bool? {
        lock.withLock { $0[flag.rawValue] }
    }

    /// Lo último que la app recibió de PostHog, leído desde el App Group (widget, Share Extension).
    static func shared(_ flag: FeatureFlag) -> Bool? {
        LumbreShared.flags[flag.rawValue]
    }
}

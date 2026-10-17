import Foundation

/// Temas puente (paso 92, flag `bridge_topics`): la Red tiene mucho de dos dominios que casi no se cruzaron
/// y Lumbre sugiere 2 o 3 temas para leer que los unan. Solo temas: nunca obras ni links.
/// Hay una sugerencia por semana como mucho (`POST /bridge-topics`).
public struct BridgeTopics: Hashable, Sendable, Identifiable {
    public let id: UUID
    /// Los dos dominios que une, en orden.
    public let domains: [Domain]
    /// De 2 a 3.
    public let topics: [BridgeTopic]
    public let createdAt: Date

    public init(id: UUID = UUID(), domains: [Domain], topics: [BridgeTopic], createdAt: Date = .now) {
        self.id = id
        self.domains = domains
        self.topics = topics
        self.createdAt = createdAt
    }
}

public struct BridgeTopic: Hashable, Sendable {
    /// El nombre del tema, para buscarlo tal cual ("Bioarte").
    public let title: String
    /// Qué tiene de cada uno de los dos dominios, en una oración.
    public let why: String

    public init(title: String, why: String) {
        self.title = title
        self.why = why
    }
}

// MARK: - DTO

/// Respuesta de `POST /bridge-topics`.
struct BridgeEnvelopeDTO: Decodable, Sendable {
    let bridge: BridgeTopicsDTO?
}

struct BridgeTopicsDTO: Decodable, Sendable {
    struct Topic: Decodable, Sendable {
        let title: String
        let why: String
    }

    let id: UUID
    let domains: [DomainDTO]
    let topics: [Topic]
    let createdAt: Date

    /// nil si no trae lo que la app puede mostrar (dos dominios y al menos dos temas).
    var model: BridgeTopics? {
        guard domains.count == 2, topics.count >= 2 else { return nil }
        return BridgeTopics(id: id, domains: domains.map(\.model), topics: topics.prefix(3).map { BridgeTopic(title: $0.title, why: $0.why) },
                            createdAt: createdAt)
    }
}

// MARK: - Mock

extension MockData {
    /// Neuronas propias (listas, sin las de la biblioteca ni las que nacieron de una chispa) que necesita cada dominio. Igual que el backend
    /// (`bridge_topics_min_concepts` y `bridge_topics_max_crossings` de app_config).
    static let bridgeMinConcepts = 5
    static let bridgeMaxCrossings = 1

    /// La misma regla que `bridge_domain_pair()`: entre los dominios con al menos 5 neuronas, el par más grande
    /// y parejo con como mucho 1 chispa entre los dos. Los temas son fijos para unos pares conocidos.
    static func bridgeTopics(concepts: [Concept], sparks: [Spark]) -> BridgeTopics? {
        var counts: [String: Int] = [:]
        var domainsBySlug: [String: Domain] = [:]
        for concept in concepts where concept.status == .ready && !concept.fromLibrary && concept.sourceType != .spark {
            guard let domain = concept.category?.domain else { continue }
            counts[domain.slug, default: 0] += 1
            domainsBySlug[domain.slug] = domain
        }
        let strong = counts.filter { $0.value >= bridgeMinConcepts }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(6)
        func crossings(_ a: String, _ b: String) -> Int {
            sparks.filter {
                let pair = Set([$0.conceptA.category?.domain?.slug, $0.conceptB.category?.domain?.slug].compactMap { $0 })
                return pair == [a, b]
            }.count
        }
        let candidates = strong.flatMap { a in strong.compactMap { b -> (String, String, Int, Int)? in
            guard a.key < b.key, crossings(a.key, b.key) <= bridgeMaxCrossings else { return nil }
            return (a.key, b.key, a.value, b.value)
        } }
        guard let best = candidates.max(by: { lhs, rhs in
            (min(lhs.2, lhs.3), lhs.2 + lhs.3) < (min(rhs.2, rhs.3), rhs.2 + rhs.3)
        }), let a = domainsBySlug[best.0], let b = domainsBySlug[best.1] else { return nil }

        let english = Locale.current.language.languageCode?.identifier == "en"
        let topics = bridgeTopicsByPair["\(a.slug)|\(b.slug)"].map { english ? $0.en : $0.es } ?? (english
            ? [BridgeTopic(title: "History of \(a.name) and \(b.name)", why: "How both worlds shaped each other over time."),
               BridgeTopic(title: "\(a.name) methods in \(b.name)", why: "Tools from one world applied to the problems of the other.")]
            : [BridgeTopic(title: "Historia de \(a.name.lowercased()) y \(b.name.lowercased())", why: "Cómo se influyeron los dos mundos a lo largo del tiempo."),
               BridgeTopic(title: "Métodos de \(a.name.lowercased()) en \(b.name.lowercased())", why: "Herramientas de un mundo aplicadas a los problemas del otro.")])
        // Mismo id para el mismo par: así "la de esta semana" no cambia entre pantallas.
        let hex = String(format: "%012llx", UInt64(truncatingIfNeeded: "\(a.slug)|\(b.slug)".utf8.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1)) &* 1099511628211 }) & 0xFFFF_FFFF_FFFF)
        return BridgeTopics(id: UUID(uuidString: "B0000000-0000-4000-8000-\(hex)") ?? UUID(), domains: [a, b], topics: topics,
                            createdAt: Calendar.current.startOfDay(for: .now))
    }

    private static let bridgeTopicsByPair: [String: (es: [BridgeTopic], en: [BridgeTopic])] = [
        "biologia|tecnologia": (
            es: [BridgeTopic(title: "Algoritmos evolutivos", why: "Programas que mejoran por selección y mutación, como las especies."),
                 BridgeTopic(title: "Bioinformática", why: "Software y datos para leer genomas y proteínas."),
                 BridgeTopic(title: "Computación con ADN", why: "Usar moléculas de ADN para guardar datos y hacer cálculos.")],
            en: [BridgeTopic(title: "Evolutionary algorithms", why: "Programs that improve through selection and mutation, like species do."),
                 BridgeTopic(title: "Bioinformatics", why: "Software and data to read genomes and proteins."),
                 BridgeTopic(title: "DNA computing", why: "Using DNA molecules to store data and run computations.")]
        ),
    ]

    /// Neuronas de biología y de tecnología, viejas (quedan al final de la Red): con ellas la Red de prueba tiene
    /// dos dominios fuertes que nunca se cruzaron, y aparecen los temas puente.
    static var bridgeConcepts: [Concept] {
        [
            Concept(category: category("biologia"), title: "Quorum sensing",
                    thesis: t("Las bacterias actúan juntas recién cuando son suficientes: miden cuántas hay por las señales que sueltan.", "Bacteria only act together once there are enough of them: they count each other through the signals they release."),
                    principle: t("Un grupo decide cuando la señal acumulada pasa un umbral.", "A group decides when the accumulated signal crosses a threshold."), distilled: true, confidence: .high,
                    sourceType: .link, sourceURL: URL(string: "https://example.com/quorum"), sourceTitle: t("Cómo hablan las bacterias", "How bacteria talk"),
                    createdAt: daysAgo(26)),
            Concept(category: category("biologia"), title: t("Estigmergia", "Stigmergy"),
                    thesis: t("Las hormigas se coordinan sin hablarse: cada una deja un rastro que cambia lo que hace la siguiente.", "Ants coordinate without talking: each leaves a trail that changes what the next one does."),
                    sourceType: .voice, createdAt: daysAgo(31)),
            Concept(category: category("biologia"), title: "Homeostasis",
                    thesis: t("El cuerpo corrige solo cualquier desvío para mantener la temperatura y el azúcar estables.", "The body corrects any drift on its own to keep temperature and sugar steady."),
                    sourceType: .scan, createdAt: daysAgo(37)),
            Concept(category: category("biologia"), title: t("Simbiosis", "Symbiosis"),
                    thesis: t("Dos especies distintas que se necesitan terminan diseñadas una para la otra.", "Two different species that need each other end up designed for one another."),
                    sourceType: .text, createdAt: daysAgo(44)),
            Concept(category: category("biologia"), title: t("Selección natural", "Natural selection"),
                    thesis: t("Lo que sobrevive no es lo mejor en abstracto sino lo que mejor encaja en su entorno de hoy.", "What survives is not the best in the abstract but what best fits its environment today."),
                    sourceType: .selection, sourceTitle: t("El origen de las especies", "On the Origin of Species"), createdAt: daysAgo(52)),
            Concept(category: category("tecnologia"), title: t("Caché", "Cache"),
                    thesis: t("Guardar cerca lo que se usa seguido hace rápido casi todo sin cambiar el sistema.", "Keeping what you use often close by makes almost everything fast without changing the system."),
                    sourceType: .text, createdAt: daysAgo(28)),
            Concept(category: category("tecnologia"), title: "Feature flags",
                    thesis: t("Separar publicar de prender deja probar con pocos y apagar sin volver atrás.", "Separating shipping from turning on lets you test with a few and switch off without rolling back."),
                    sourceType: .voice, createdAt: daysAgo(35)),
            Concept(category: category("tecnologia"), title: "Backpressure",
                    thesis: t("Un sistema sano le avisa al que manda datos que vaya más despacio en vez de romperse.", "A healthy system tells whoever sends data to slow down instead of breaking."),
                    sourceType: .link, sourceURL: URL(string: "https://example.com/backpressure"), sourceTitle: "Backpressure explained",
                    createdAt: daysAgo(47)),
            Concept(category: category("tecnologia"), title: t("Refactor continuo", "Continuous refactoring"),
                    thesis: t("Mejorar el código de a poco todos los días sale más barato que una reescritura grande.", "Improving the code a little every day is cheaper than a big rewrite."),
                    sourceType: .text, createdAt: daysAgo(60)),
        ]
    }
}

import Foundation

/// Backend de prueba en memoria, para previews y el argumento `-mock`: arranca con datos fijos
/// y recuerda lo que se guarda mientras la app está abierta. Simula la latencia de la red.
public final class MockLumbreAPI: LumbreAPI {
    private let latency: Duration
    private let store: MockStore

    /// - Parameter onboarded: false arranca como un invitado nuevo, sin bóveda, para probar el onboarding.
    /// `plan` pisa el plan del perfil de prueba (por ejemplo, `.pro` para probar el planificador).
    public init(latency: Duration = .milliseconds(350), onboarded: Bool = true, plan: Plan? = nil) {
        self.latency = latency
        store = MockStore(onboarded: onboarded, plan: plan)
    }

    // MARK: Sesión y perfil

    public func profile() async throws -> Profile {
        try await wait()
        return await store.profile
    }

    public func updateProfile(_ update: ProfileUpdate) async throws -> Profile {
        try await wait()
        return await store.update(update)
    }

    public func credits() async throws -> [Credit] {
        try await wait()
        return await store.credits()
    }

    public func signOut() async throws {
        try await wait()
        await store.reset(onboarded: false)
    }

    public func deleteAccount() async throws {
        try await wait()
        await store.reset(onboarded: false)
    }

    public func exportData() async throws -> Data {
        try await wait()
        let concepts = await store.concepts.map { ["title": $0.title, "thesis": $0.thesis, "category": $0.category?.name ?? ""] }
        return try JSONSerialization.data(withJSONObject: ["concepts": concepts], options: [.prettyPrinted, .sortedKeys])
    }

    public func registerPushToken(_ token: String, sandbox: Bool) async throws {}

    // MARK: Hoy y chispas

    public func today() async throws -> TodayState {
        try await wait()
        return await store.today()
    }

    public func revealSpark(id: Spark.ID) async throws {
        try await wait()
        await store.setStatus(.revealed, of: id)
    }

    public func saveSpark(id: Spark.ID, projectID: Project.ID?) async throws {
        try await wait()
        await store.save(sparkID: id, projectID: projectID)
    }

    public func sendFeedback(sparkID: Spark.ID, feedback: SparkFeedback) async throws {
        try await wait()
        await store.feedback(sparkID: sparkID, feedback: feedback)
    }

    public func requestSpark(pick: (Concept.ID, Concept.ID)?) async throws -> Spark {
        try await Task.sleep(for: latency * 3)
        return try await store.extraSpark(pick: pick)
    }

    public func recentSparks() async throws -> [Spark] {
        try await wait()
        return await store.recent()
    }

    public func spark(id: Spark.ID) async throws -> Spark {
        try await wait()
        guard let spark = await store.sparks.first(where: { $0.id == id }) else { throw LumbreAPIError.unexpected }
        return spark
    }

    public func reportSpark(id: Spark.ID, reason: ReportReason, note: String?) async throws {
        try await wait()
    }

    // MARK: Bóveda

    public func concepts() async throws -> [Concept] {
        try await wait()
        return await store.concepts
    }

    public func searchConcepts(_ query: String) async throws -> [Concept] {
        try await wait()
        let words = query.lowercased().split(separator: " ").map(String.init)
        return await store.concepts.filter { concept in
            let haystack = "\(concept.title) \(concept.thesis) \(concept.category?.name ?? "")"
            return words.contains { haystack.localizedStandardContains($0) }
        }
    }

    public func concept(id: Concept.ID) async throws -> Concept {
        try await wait()
        guard let concept = await store.concepts.first(where: { $0.id == id }) else { throw LumbreAPIError.unexpected }
        return concept
    }

    public func sparks(withConcept id: Concept.ID) async throws -> [Spark] {
        try await wait()
        return await store.sparks.filter { $0.conceptA.id == id || $0.conceptB.id == id }
    }

    public func updateConcept(id: Concept.ID, _ update: ConceptUpdate) async throws -> Concept {
        try await wait()
        return try await store.update(conceptID: id, update)
    }

    public func deleteConcept(id: Concept.ID) async throws {
        try await wait()
        await store.deleteConcept(id)
    }

    public func categories() async throws -> [Category] {
        try await wait()
        return await store.categories.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public func renameCategory(id: Category.ID, to name: String) async throws {
        try await wait()
        await store.renameCategory(id, to: name)
    }

    public func deleteCategory(id: Category.ID) async throws {
        try await wait()
        await store.deleteCategory(id)
    }

    public func capture(_ request: CaptureRequest) async throws -> CaptureResult {
        try await Task.sleep(for: request.distill ? latency * 4 : latency)
        return try await store.capture(request)
    }

    // MARK: Proyectos y planificador

    public func projects() async throws -> [Project] {
        try await wait()
        return await store.projectList()
    }

    public func createProject(name: String) async throws -> Project {
        try await wait()
        return try await store.createProject(name: name)
    }

    public func renameProject(id: Project.ID, to name: String) async throws {
        try await wait()
        await store.renameProject(id, to: name)
    }

    public func deleteProject(id: Project.ID) async throws {
        try await wait()
        await store.deleteProject(id)
    }

    public func sparks(inProject id: Project.ID) async throws -> [Spark] {
        try await wait()
        return await store.sparks.filter { $0.projectID == id }
    }

    public func exportProjectMarkdown(id: Project.ID) async throws -> String {
        try await wait()
        let name = await store.projects.first { $0.id == id }?.name ?? ""
        let sparks = await store.sparks.filter { $0.projectID == id }
        return MarkdownExport.project(name: name, sparks: sparks, plans: [:])
    }

    public func plannerMessages(sparkID: Spark.ID) async throws -> [PlannerMessage] {
        try await wait()
        return await store.messages[sparkID] ?? []
    }

    public func sendPlannerMessage(sparkID: Spark.ID, text: String, mode: PlannerMode, method: PlannerMethod) -> AsyncThrowingStream<String, Error> {
        let store = store
        let latency = latency
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard await store.profile.isPro else { throw LumbreAPIError.proRequired }
                    let history = await store.messages[sparkID] ?? []
                    await store.appendMessage(sparkID: sparkID, role: .user, content: text, mode: mode)
                    let reply = method == .disney
                        ? MockData.disneyReply(history: history, to: text)
                        : MockData.plannerReply(to: text, mode: mode)
                    var sent = ""
                    for word in reply.split(separator: " ", omittingEmptySubsequences: false) {
                        try await Task.sleep(for: latency / 10)
                        let chunk = sent.isEmpty ? String(word) : " " + word
                        sent += chunk
                        continuation.yield(chunk)
                    }
                    await store.appendMessage(sparkID: sparkID, role: .assistant, content: sent, mode: mode)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Desarrollo

    public func setPlanForDevelopment(_ plan: Plan) async throws {
        try await wait()
        await store.setPlan(plan)
    }

    private func wait() async throws {
        try await Task.sleep(for: latency)
    }
}

/// Estado del mock. Un actor para que las pantallas puedan pedir cosas en paralelo.
private actor MockStore {
    var profile: Profile
    var categories: [Category]
    var concepts: [Concept]
    var sparks: [Spark]
    var projects: [Project]
    var messages: [Spark.ID: [PlannerMessage]] = [:]
    var extrasUsedToday = 0
    var capturesToday = 0

    init(onboarded: Bool, plan: Plan? = nil) {
        let state = Self.initialState(onboarded: onboarded)
        (profile, categories, concepts, sparks, projects, messages) = state
        if let plan { profile = Self.profile(state.0, with: plan) }
    }

    func reset(onboarded: Bool) {
        (profile, categories, concepts, sparks, projects, messages) = Self.initialState(onboarded: onboarded)
        extrasUsedToday = 0
        capturesToday = 0
    }

    private static func initialState(onboarded: Bool) -> (Profile, [Category], [Concept], [Spark], [Project], [Spark.ID: [PlannerMessage]]) {
        if onboarded {
            return (MockData.profile, MockData.categories, MockData.concepts, [MockData.todaySpark] + MockData.recentSparks,
                    [MockData.project], [MockData.recentSparks[0].id: MockData.plannerThread])
        }
        let guest = Profile(creativeProfiles: [], sparkTime: .default, timezone: TimeZone.current.identifier, locale: "es", plan: .guest, email: nil, isOnboarded: false)
        return (guest, [], [], [], [], [:])
    }

    func update(_ update: ProfileUpdate) -> Profile {
        if let value = update.creativeProfiles { profile.creativeProfiles = Array(value.prefix(2)) }
        if let value = update.sparkTime { profile.sparkTime = value }
        if let value = update.timezone { profile.timezone = value }
        if let value = update.locale { profile.locale = value }
        if update.completeOnboarding { profile.isOnboarded = true }
        return profile
    }

    func setPlan(_ plan: Plan) {
        profile = Self.profile(profile, with: plan)
    }

    private static func profile(_ profile: Profile, with plan: Plan) -> Profile {
        Profile(creativeProfiles: profile.creativeProfiles, sparkTime: profile.sparkTime, timezone: profile.timezone, locale: profile.locale, plan: plan, email: plan == .guest ? nil : (profile.email ?? "ana@lumbre.test"), isOnboarded: profile.isOnboarded)
    }

    func credits() -> [Credit] {
        switch profile.plan {
        case .guest:
            return [Credit(kind: .capture, period: "day", max: 10, remaining: max(0, 10 - capturesToday)),
                    Credit(kind: .projects, period: "total", max: 1, remaining: max(0, 1 - projects.count))]
        case .free:
            return [Credit(kind: .capture, period: "day", max: 30, remaining: max(0, 30 - capturesToday)),
                    Credit(kind: .distill, period: "month", max: 5, remaining: 3),
                    Credit(kind: .sparkExtra, period: "day", max: 2, remaining: extraRemaining),
                    Credit(kind: .projects, period: "total", max: 1, remaining: max(0, 1 - projects.count))]
        case .pro:
            return [Credit(kind: .capture, period: "day", max: 200, remaining: 200 - capturesToday),
                    Credit(kind: .distill, period: "month", max: 300, remaining: 287),
                    Credit(kind: .sparkExtra, period: "day", max: 10, remaining: extraRemaining),
                    Credit(kind: .planner, period: "month", max: 300, remaining: 280),
                    Credit(kind: .plannerDeep, period: "month", max: 60, remaining: 58),
                    Credit(kind: .projects, period: "total", max: 1000, remaining: 1000 - projects.count)]
        }
    }

    /// Free: 1 extra cada 3 conceptos guardados hoy, hasta 2. Pro: hasta 10. Invitado: ninguna.
    var extraRemaining: Int {
        switch profile.plan {
        case .guest: 0
        case .free: max(0, min(2, capturesToday / 3) - extrasUsedToday)
        case .pro: max(0, 10 - extrasUsedToday)
        }
    }

    var todaySpark: Spark? {
        sparks.first { $0.mode == .daily && $0.scheduledFor.map(Calendar.current.isDateInToday) == true }
    }

    func today() -> TodayState {
        let daily = todaySpark
        let dailyAvailable = daily.map { $0.status == .pending || $0.status == .revealed ? 1 : 0 } ?? 0
        let extras = sparks.filter { $0.mode != .daily && Calendar.current.isDateInToday($0.createdAt) }
        let quota = SparkQuota(
            available: dailyAvailable + extraRemaining,
            total: 1 + (profile.plan == .pro ? 10 : min(2, capturesToday / 3)),
            refillsAt: MockData.nextOccurrence(of: profile.sparkTime),
            conceptsUntilExtra: profile.plan == .free ? 3 - capturesToday % 3 : 0,
            extraRemaining: extraRemaining
        )
        let pairs = concepts.count * (concepts.count - 1) / 2
        return TodayState(spark: daily, quota: quota, extras: extras, runwayDays: max(0, pairs / 3 - sparks.count), conceptCount: concepts.count)
    }

    func recent() -> [Spark] {
        sparks.filter { $0.id != todaySpark?.id }.sorted { $0.createdAt > $1.createdAt }
    }

    func setStatus(_ status: SparkStatus, of id: Spark.ID) {
        guard let index = sparks.firstIndex(where: { $0.id == id }) else { return }
        if sparks[index].status == .pending { sparks[index].status = status }
    }

    func save(sparkID: Spark.ID, projectID: Project.ID?) {
        guard let index = sparks.firstIndex(where: { $0.id == sparkID }) else { return }
        sparks[index].status = .saved
        sparks[index].projectID = projectID
        sparks[index].projectName = projects.first { $0.id == projectID }?.name
    }

    func feedback(sparkID: Spark.ID, feedback: SparkFeedback) {
        guard let index = sparks.firstIndex(where: { $0.id == sparkID }) else { return }
        sparks[index].status = .discarded
        sparks[index].feedback = feedback
    }

    func extraSpark(pick: (Concept.ID, Concept.ID)?) throws -> Spark {
        if pick != nil && profile.plan != .pro { throw LumbreAPIError.proRequired }
        guard extraRemaining > 0 else { throw LumbreAPIError.quotaExceeded }
        let pair: (Concept, Concept)
        if let pick, let a = concepts.first(where: { $0.id == pick.0 }), let b = concepts.first(where: { $0.id == pick.1 }) {
            pair = (a, b)
        } else {
            let used = Set(sparks.map { Set([$0.conceptA.id, $0.conceptB.id]) })
            let candidates = concepts.flatMap { a in concepts.compactMap { b -> (Concept, Concept)? in
                a.id.uuidString < b.id.uuidString && a.category != b.category && !used.contains([a.id, b.id]) ? (a, b) : nil
            } }
            guard let chosen = candidates.randomElement() else { throw LumbreAPIError.notEnoughConcepts }
            pair = chosen
        }
        extrasUsedToday += 1
        let spark = Spark(
            conceptA: pair.0, conceptB: pair.1,
            title: "\(pair.0.title) × \(pair.1.title)",
            body: "¿Y si “\(pair.0.title.lowercased())” funcionara como “\(pair.1.title.lowercased())”? \(pair.1.thesis)",
            mode: pick == nil ? .extra : .pick, status: .pending, createdAt: .now
        )
        sparks.insert(spark, at: 0)
        return spark
    }

    func update(conceptID: Concept.ID, _ update: ConceptUpdate) throws -> Concept {
        guard let index = concepts.firstIndex(where: { $0.id == conceptID }) else { throw LumbreAPIError.unexpected }
        if let title = update.title { concepts[index].title = title }
        if let thesis = update.thesis { concepts[index].thesis = thesis }
        if let name = update.categoryName { concepts[index].category = findOrCreateCategory(name).category }
        if update.confirm { concepts[index].status = .ready }
        return concepts[index]
    }

    func deleteConcept(_ id: Concept.ID) {
        concepts.removeAll { $0.id == id }
        sparks.removeAll { $0.conceptA.id == id || $0.conceptB.id == id }
    }

    func renameCategory(_ id: Category.ID, to name: String) {
        guard let index = categories.firstIndex(where: { $0.id == id }) else { return }
        let renamed = Category(id: id, name: name, domain: categories[index].domain)
        categories[index] = renamed
        for i in concepts.indices where concepts[i].category?.id == id { concepts[i].category = renamed }
    }

    func deleteCategory(_ id: Category.ID) {
        categories.removeAll { $0.id == id }
        for i in concepts.indices where concepts[i].category?.id == id { concepts[i].category = nil }
    }

    private func findOrCreateCategory(_ name: String) -> (category: Category, created: Bool) {
        let key = MockData.normalized(name)
        if let existing = categories.first(where: { MockData.normalized($0.name) == key }) {
            return (existing, false)
        }
        let category = Category(name: name.split(whereSeparator: \.isWhitespace).joined(separator: " "))
        categories.append(category)
        return (category, true)
    }

    func capture(_ request: CaptureRequest) throws -> CaptureResult {
        let limit = profile.plan == .guest ? 10 : profile.plan == .free ? 30 : 200
        guard capturesToday < limit else { throw LumbreAPIError.quotaExceeded }
        let thesis = request.thesis?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let canDistill = request.distill && profile.plan != .guest
        if thesis.isEmpty && !canDistill { throw LumbreAPIError.invalidThesis }
        if categories.count >= 50 && !categories.contains(where: { MockData.normalized($0.name) == MockData.normalized(request.category) }) {
            throw LumbreAPIError.tooManyCategories
        }
        let (category, created) = findOrCreateCategory(request.category)
        let sourceURL: URL? = switch request.source {
        case .link(let url): url
        case .selection(let url): url
        default: nil
        }
        let distilled = canDistill && (thesis.split(separator: " ").count >= 30 || thesis.isEmpty || request.source.sourceType == .link)
        let finalThesis = thesis.isEmpty ? "Una idea sacada de \(request.sourceTitle ?? sourceURL?.host() ?? "lo que guardaste")." : thesis
        let concept = Concept(
            category: category,
            title: String(finalThesis.prefix(60)),
            thesis: String(finalThesis.prefix(600)),
            principle: distilled ? "Un principio de fondo que se puede llevar a otro mundo." : nil,
            status: distilled && thesis.isEmpty ? .draft : .ready,
            distilled: distilled,
            confidence: distilled ? (thesis.isEmpty ? .medium : .high) : nil,
            sourceType: request.source.sourceType,
            sourceURL: sourceURL,
            sourceTitle: request.sourceTitle,
            excerpt: request.excerpt.map { String($0.prefix(500)) },
            createdAt: .now
        )
        concepts.insert(concept, at: 0)
        capturesToday += 1
        return CaptureResult(
            conceptID: concept.id, categoryID: category.id, categoryCreated: created,
            concepts: [concept],
            distillation: distilled ? (concept.status == .draft ? .medium : .high) : .none
        )
    }

    func projectList() -> [Project] {
        projects.map { project in
            Project(id: project.id, name: project.name, sparkCount: sparks.filter { $0.projectID == project.id }.count, createdAt: project.createdAt)
        }
    }

    func createProject(name: String) throws -> Project {
        let limit = profile.plan == .pro ? 1000 : 1
        guard projects.count < limit else { throw LumbreAPIError.tooManyProjects }
        let project = Project(name: name, createdAt: .now)
        projects.append(project)
        return project
    }

    func renameProject(_ id: Project.ID, to name: String) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].name = name
        for i in sparks.indices where sparks[i].projectID == id { sparks[i].projectName = name }
    }

    func deleteProject(_ id: Project.ID) {
        projects.removeAll { $0.id == id }
        for i in sparks.indices where sparks[i].projectID == id {
            sparks[i].projectID = nil
            sparks[i].projectName = nil
        }
    }

    func appendMessage(sparkID: Spark.ID, role: PlannerRole, content: String, mode: PlannerMode) {
        let id = (messages.values.flatMap { $0 }.map(\.id).max() ?? 0) + 1
        messages[sparkID, default: []].append(PlannerMessage(id: id, role: role, content: content, mode: mode, createdAt: .now))
    }
}

public enum MockData {
    public static let domains: [Domain] = [
        Domain(slug: "arquitectura", name: "Arquitectura y urbanismo", symbol: "building.2"),
        Domain(slug: "tecnologia", name: "Tecnología", symbol: "cpu"),
        Domain(slug: "ingenieria", name: "Ingeniería", symbol: "gearshape.2"),
        Domain(slug: "marketing", name: "Marketing y comunicación", symbol: "megaphone"),
        Domain(slug: "historia", name: "Historia y arqueología", symbol: "building.columns"),
        Domain(slug: "cocina", name: "Cocina y gastronomía", symbol: "fork.knife"),
        Domain(slug: "economia", name: "Economía y finanzas", symbol: "chart.line.uptrend.xyaxis"),
        Domain(slug: "biologia", name: "Biología y naturaleza", symbol: "leaf"),
    ]

    /// Nombres cortos, como los escribiría un usuario; mismos que el seed de la base.
    public static let categories: [Category] = zip(
        ["arquitectura", "tecnologia", "ingenieria", "marketing", "historia", "cocina", "economia", "biologia"],
        ["Urbanismo", "Software", "Ingeniería", "Marketing", "Historia", "Cocina", "Economía", "Biología"]
    )
    .map { slug, name in Category(name: name, domain: domains.first { $0.slug == slug }) }
    .sorted { $0.name < $1.name }

    public static let profile = Profile(
        creativeProfiles: [.software, .curiosity],
        sparkTime: .default,
        timezone: "America/Argentina/Buenos_Aires",
        locale: "es",
        plan: .free,
        email: "ana@lumbre.test",
        isOnboarded: true
    )

    private static func category(_ slug: String) -> Category {
        categories.first { $0.domain?.slug == slug }!
    }

    private static func daysAgo(_ days: Double) -> Date {
        Date.now.addingTimeInterval(-days * 86_400)
    }

    public static let concepts: [Concept] = [
        Concept(category: category("marketing"), title: "Escasez intencional",
                thesis: "Limitar la oferta sube el valor percibido y la atención.",
                sourceType: .voice, createdAt: daysAgo(0.1)),
        Concept(category: category("arquitectura"), title: "Onda verde de semáforos",
                thesis: "Sincronizar semáforos crea un flujo continuo a velocidad constante.",
                principle: "Coordinar los tiempos de varias etapas evita las esperas entre ellas.",
                distilled: true, confidence: .high,
                sourceType: .text, createdAt: daysAgo(1)),
        Concept(category: category("ingenieria"), title: "Separación ciclónica",
                thesis: "Un flujo en espiral separa partículas por fuerza centrífuga, sin filtro.",
                principle: "Un movimiento rotatorio ordena elementos por su masa.",
                distilled: true, confidence: .high,
                sourceType: .link, sourceURL: URL(string: "https://example.com/ciclones"),
                sourceTitle: "Cómo funcionan los ciclones industriales", createdAt: daysAgo(2)),
        Concept(category: category("tecnologia"), title: "Code review",
                thesis: "Revisar cambios en pares reduce errores y reparte el conocimiento del código.",
                sourceType: .selection, sourceTitle: "Engineering practices",
                excerpt: "Code review is the single biggest thing you can do to improve your code.", createdAt: daysAgo(3)),
        Concept(category: category("cocina"), title: "Fermentación lenta",
                thesis: "El tiempo transforma ingredientes simples en sabores complejos sin agregar nada.",
                sourceType: .screenshot, createdAt: daysAgo(5)),
        Concept(category: category("historia"), title: "Ruinas como archivo",
                thesis: "Lo que queda de una ciudad cuenta cómo vivía la gente mejor que sus documentos.",
                sourceType: .link, sourceURL: URL(string: "https://example.com/pompeya"),
                sourceTitle: "Pompeya, capa por capa", createdAt: daysAgo(8)),
        Concept(category: category("economia"), title: "Interés compuesto",
                thesis: "Pequeñas ganancias que se reinvierten crecen de forma exponencial con el tiempo.",
                sourceType: .scan, createdAt: daysAgo(12)),
        Concept(category: category("biologia"), title: "Micorrizas",
                thesis: "Los hongos conectan las raíces de un bosque y reparten nutrientes entre árboles.",
                status: .draft, distilled: true, confidence: .medium,
                sourceType: .pdf, sourceTitle: "Redes subterráneas.pdf", createdAt: daysAgo(20)),
    ]

    public static let todaySpark = Spark(
        conceptA: concepts[1],
        conceptB: concepts[3],
        title: "Semáforos × code review",
        body: "Si un PR se aprueba rápido, los siguientes del mismo autor entran en una “onda verde” con revisión prioritaria. Premia los PR chicos sin reglas nuevas.",
        status: .pending,
        scheduledFor: Calendar.current.startOfDay(for: .now),
        createdAt: .now
    )

    public static let project = Project(name: "Canal de YouTube", createdAt: daysAgo(4))

    public static let recentSparks: [Spark] = [
        Spark(
            conceptA: Concept(category: category("marketing"), title: "Formato podcast",
                              thesis: "Una conversación larga genera confianza que un anuncio no logra.",
                              sourceType: .audio, createdAt: daysAgo(9)),
            conceptB: concepts[5],
            title: "Podcast × ruinas",
            body: "Un episodio por capa de excavación: cada uno cuenta una época de la misma ciudad con lo que quedó enterrado.",
            status: .saved,
            projectID: project.id,
            projectName: project.name,
            scheduledFor: Calendar.current.startOfDay(for: daysAgo(1)),
            createdAt: daysAgo(1)
        ),
        Spark(
            conceptA: concepts[4],
            conceptB: concepts[6],
            title: "Fermentación × interés compuesto",
            body: "Un newsletter que no se promociona: cada edición recupera y mejora una idea vieja en vez de buscar una nueva.",
            status: .revealed,
            scheduledFor: Calendar.current.startOfDay(for: daysAgo(2)),
            createdAt: daysAgo(2)
        ),
    ]

    public static let plannerThread: [PlannerMessage] = [
        PlannerMessage(id: 1, role: .user, content: "Armame un backlog para el primer mes.", createdAt: daysAgo(1)),
        PlannerMessage(id: 2, role: .assistant, content: "1. Elegir la ciudad y 4 capas de excavación.\n2. Guion del episodio piloto.\n3. Grabar con un arqueólogo invitado.\n4. Publicar y medir retención al minuto 3.", createdAt: daysAgo(1)),
    ]

    public static let quota: SparkQuota = SparkQuota(
        available: 1,
        total: 1,
        refillsAt: nextOccurrence(of: .default),
        conceptsUntilExtra: 3
    )

    /// Los tres cuartos de Disney sin modelo, con la misma lógica que el proveedor local del backend:
    /// avanza por respuestas en cada cuarto (Soñador 3, Realista 2, Crítico 3) y cierra con la síntesis.
    static func disneyReply(history: [PlannerMessage], to text: String) -> String {
        var current: PlannerRoom?
        var turns: [PlannerRoom: Int] = [:]
        for message in history {
            if message.role == .assistant {
                current = message.room ?? current
            } else if let current {
                turns[current, default: 0] += 1
            }
        }
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let skip = ["siguiente cuarto", "pasemos", "pasamos"].contains { folded.contains($0) }
        func answers(_ room: PlannerRoom) -> Int { (turns[room] ?? 0) + (current == room ? 1 : 0) }
        func mark(_ room: PlannerRoom, _ body: String) -> String { "[[room:\(room.rawValue)]]\n\n" + body }

        switch current {
        case nil:
            return mark(.dreamer, "Entramos al cuarto del Soñador. Imaginá que esta chispa funciona por completo: sin presupuesto, sin reglas y sin nadie que diga que no. ¿Cómo se ve? ¿Quién la usa y qué cambia en su día?")
        case .dreamer where !skip && answers(.dreamer) == 1:
            return mark(.dreamer, "Me encanta. Ahora más grande: ¿qué pasa si en vez de unas pocas personas lo usa todo un país?")
        case .dreamer where !skip && answers(.dreamer) == 2:
            return mark(.dreamer, "Una vez más, sin techo: si dentro de diez años esto fuera lo primero que la gente piensa cuando escucha la idea, ¿cómo sería?")
        case .dreamer:
            return mark(.realist, "Pasamos al cuarto del Realista. Para volver real ese sueño: ¿cuáles son los pasos, qué gente hace falta, cuánta plata y qué es lo primero que tiene que pasar?")
        case .realist where !skip && answers(.realist) == 1:
            return mark(.realist, "Bajemos lo primero a tierra: ¿qué podés hacer esta semana, con lo que ya tenés, para que eso pase?")
        case .realist:
            return mark(.critic, "Pasamos al cuarto del Crítico. Primera pregunta: ¿qué le falta a esto?")
        case .critic where !skip && answers(.critic) == 1:
            return mark(.critic, "Segunda: ¿qué puede salir mal?")
        case .critic where !skip && answers(.critic) == 2:
            return mark(.critic, "Última: ¿quién odiaría esto, y por qué?")
        case .critic:
            let least = [PlannerRoom.dreamer, .realist, .critic].min { (turns[$0] ?? 0) < (turns[$1] ?? 0) } ?? .dreamer
            let names: [PlannerRoom: String] = [.dreamer: "Soñador", .realist: "Realista", .critic: "Crítico"]
            return mark(.plan, """
            **El sueño**: que esta chispa sea lo que todos usan sin pensarlo.

            **El plan**:
            1. Esta semana: probar la versión más chica con 3 personas.
            2. Armar el mecanismo central con la primera neurona.
            3. Sumar la segunda como el detalle que lo hace distinto.
            4. Medir si vuelven solos.
            5. Decidir qué se corta y qué crece.

            **Los tres agujeros**:
            - Falta saber quién lo pide hoy. Arreglo: hablar con cinco personas antes de construir.
            - Puede salir caro. Arreglo: hacerlo a mano la primera vez.
            - Lo odiarían quienes viven del sistema actual. Arreglo: sumarlos como aliados desde el paso 1.

            **El cuarto que salteás**: el \(names[least] ?? "Soñador"). Volvé ahí la próxima vez antes de pasar al siguiente.
            """)
        case .plan:
            return mark(.plan, "Elegí una sola cosa del plan para esta semana y medí si cambia algo.")
        }
    }

    static func plannerReply(to text: String, mode: PlannerMode) -> String {
        mode == .deep
            ? "Plan en tres etapas. Primero, validá el problema con 5 personas. Segundo, armá la versión más chica que lo resuelva en una semana. Tercero, medí si vuelven solos. El riesgo principal: que la idea sea linda pero nadie la necesite hoy."
            : "Buena pregunta. Arrancaría por lo más chico que puedas probar esta semana y lo mediría con una sola métrica."
    }

    static func normalized(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Próxima vez que llega la hora de la chispa, hoy o mañana.
    public static func nextOccurrence(of time: SparkTime, after now: Date = .now, calendar: Calendar = .current) -> Date {
        let today = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: now) ?? now
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }
}

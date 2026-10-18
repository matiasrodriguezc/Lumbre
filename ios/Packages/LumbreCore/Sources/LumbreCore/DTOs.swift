import Foundation

// Formas del JSON del backend (`backend/openapi.yaml`, components/schemas), las mismas para PostgREST
// (los `select` usan alias para que coincidan) y para las Edge Functions. También son lo que guarda la caché.
// Las claves se pasan de snake_case con `LumbreJSON`. Los textos de estado desconocidos caen en un valor seguro.

struct DomainDTO: Codable, Sendable {
    let slug: String
    let nameEs: String
    let nameEn: String
    let symbolIos: String?

    init(slug: String, nameEs: String, nameEn: String, symbolIos: String?) {
        self.slug = slug
        self.nameEs = nameEs
        self.nameEn = nameEn
        self.symbolIos = symbolIos
    }

    init(_ model: Domain) {
        self.init(slug: model.slug, nameEs: model.name, nameEn: model.name, symbolIos: model.symbol)
    }

    var model: Domain {
        let english = Locale.current.language.languageCode?.identifier == "en"
        return Domain(slug: slug, name: english ? nameEn : nameEs, symbol: symbolIos ?? "circle.hexagongrid")
    }
}

struct CategoryDTO: Codable, Sendable {
    let id: UUID
    let name: String
    let domain: DomainDTO?

    init(_ model: Category) {
        id = model.id
        name = model.name
        domain = model.domain.map(DomainDTO.init)
    }

    var model: Category { Category(id: id, name: name, domain: domain?.model) }
}

struct ConceptDTO: Codable, Sendable {
    let id: UUID
    let title: String
    let thesis: String
    let principle: String?
    let status: String?
    let distilled: Bool?
    let confidence: String?
    let sourceType: String
    let sourceUrl: String?
    let sourceTitle: String?
    let excerpt: String?
    let fromLibrary: Bool?
    let originSparkId: UUID?
    let originLo: UUID?
    let originHi: UUID?
    let createdAt: Date
    let category: CategoryDTO?

    init(_ model: Concept) {
        id = model.id
        title = model.title
        thesis = model.thesis
        principle = model.principle
        status = model.status.rawValue
        distilled = model.distilled
        confidence = model.confidence?.rawValue
        sourceType = model.sourceType.rawValue
        sourceUrl = model.sourceURL?.absoluteString
        sourceTitle = model.sourceTitle
        excerpt = model.excerpt
        fromLibrary = model.fromLibrary
        originSparkId = model.originSparkID
        originLo = model.originConceptIDs.first
        originHi = model.originConceptIDs.dropFirst().first
        createdAt = model.createdAt
        category = model.category.map(CategoryDTO.init)
    }

    var model: Concept {
        Concept(
            id: id,
            category: category?.model,
            title: title,
            thesis: thesis,
            principle: principle,
            status: status.flatMap(ConceptStatus.init(rawValue:)) ?? .ready,
            distilled: distilled ?? false,
            confidence: confidence.flatMap(Confidence.init(rawValue:)),
            sourceType: SourceType(rawValue: sourceType) ?? .text,
            sourceURL: sourceUrl.flatMap(URL.init(string:)),
            sourceTitle: sourceTitle,
            excerpt: excerpt,
            fromLibrary: fromLibrary ?? false,
            originSparkID: originSparkId,
            originConceptIDs: [originLo, originHi].compactMap(\.self),
            createdAt: createdAt
        )
    }
}

struct SparkDTO: Codable, Sendable {
    /// PostgREST trae el nombre del proyecto anidado (`project:project_id(name)`); las Edge Functions, plano.
    struct ProjectName: Codable, Sendable {
        let name: String
    }

    let id: UUID
    /// En la base es null mientras el batch no escribió el texto.
    let title: String?
    let body: String?
    let mode: String
    let status: String
    let feedback: String?
    let projectId: UUID?
    let projectName: String?
    let project: ProjectName?
    let scheduledFor: Date?
    let createdAt: Date
    let conceptA: ConceptDTO
    let conceptB: ConceptDTO

    init(_ model: Spark) {
        id = model.id
        title = model.title
        body = model.body
        mode = model.mode.rawValue
        status = model.status.rawValue
        feedback = model.feedback?.rawValue
        projectId = model.projectID
        projectName = model.projectName
        project = nil
        scheduledFor = model.scheduledFor
        createdAt = model.createdAt
        conceptA = ConceptDTO(model.conceptA)
        conceptB = ConceptDTO(model.conceptB)
    }

    var model: Spark {
        Spark(
            id: id,
            conceptA: conceptA.model,
            conceptB: conceptB.model,
            title: title ?? "\(conceptA.title) × \(conceptB.title)",
            body: body ?? "",
            mode: SparkMode(rawValue: mode) ?? .daily,
            status: SparkStatus(rawValue: status) ?? .revealed,
            feedback: feedback.flatMap(SparkFeedback.init(rawValue:)),
            projectID: projectId,
            projectName: projectName ?? project?.name,
            scheduledFor: scheduledFor,
            createdAt: createdAt
        )
    }
}

struct QuotaDTO: Codable, Sendable {
    let available: Int
    let total: Int
    let refillsAt: Date
    let conceptsUntilExtra: Int
    let extraRemaining: Int?

    init(_ model: SparkQuota) {
        available = model.available
        total = model.total
        refillsAt = model.refillsAt
        conceptsUntilExtra = model.conceptsUntilExtra
        extraRemaining = model.extraRemaining
    }

    var model: SparkQuota {
        SparkQuota(available: available, total: total, refillsAt: refillsAt, conceptsUntilExtra: conceptsUntilExtra, extraRemaining: extraRemaining ?? 0)
    }
}

struct TodayDTO: Codable, Sendable {
    let spark: SparkDTO?
    let quota: QuotaDTO
    let extras: [SparkDTO]?
    let runwayDays: Int
    let conceptCount: Int

    init(_ model: TodayState) {
        spark = model.spark.map(SparkDTO.init)
        quota = QuotaDTO(model.quota)
        extras = model.extras.map(SparkDTO.init)
        runwayDays = model.runwayDays
        conceptCount = model.conceptCount
    }

    var model: TodayState {
        TodayState(spark: spark?.model, quota: quota.model, extras: (extras ?? []).map(\.model), runwayDays: runwayDays, conceptCount: conceptCount)
    }
}

/// Respuesta de `POST /spark`.
struct SparkEnvelopeDTO: Decodable, Sendable {
    let spark: SparkDTO
}

/// Respuesta de `POST /search`.
struct ConceptListDTO: Decodable, Sendable {
    let concepts: [ConceptDTO]
}

/// Respuesta de `POST /capture`.
struct CaptureResultDTO: Decodable, Sendable {
    let conceptId: UUID
    let categoryId: UUID
    let categoryCreated: Bool
    let concepts: [ConceptDTO]?
    let distillation: String?

    var model: CaptureResult {
        CaptureResult(
            conceptID: conceptId,
            categoryID: categoryId,
            categoryCreated: categoryCreated,
            concepts: (concepts ?? []).map(\.model),
            distillation: distillation.flatMap(DistillationOutcome.init(rawValue:)) ?? .none
        )
    }
}

/// Una fila de `credit_status()`.
struct CreditDTO: Decodable, Sendable {
    let kind: String
    let period: String
    let maxCount: Int
    /// Cupo del período: en los que se ganan, lo ganado hasta ahora.
    let available: Int?
    let remaining: Int

    var model: Credit? {
        CreditKind(rawValue: kind).map { Credit(kind: $0, period: period, max: maxCount, remaining: remaining) }
    }
}

struct ProjectDTO: Codable, Sendable {
    /// `sparks(count)` de PostgREST.
    struct Count: Codable, Sendable {
        let count: Int
    }

    let id: UUID
    let name: String
    let createdAt: Date
    let sparkCount: Int?
    let sparks: [Count]?

    init(_ model: Project) {
        id = model.id
        name = model.name
        createdAt = model.createdAt
        sparkCount = model.sparkCount
        sparks = nil
    }

    var model: Project {
        Project(id: id, name: name, sparkCount: sparkCount ?? sparks?.first?.count ?? 0, createdAt: createdAt)
    }
}

struct PlannerMessageDTO: Decodable, Sendable {
    let id: Int
    let role: String
    let content: String
    let mode: String?
    let createdAt: Date

    var model: PlannerMessage {
        PlannerMessage(
            id: id,
            role: PlannerRole(rawValue: role) ?? .assistant,
            content: content,
            mode: mode.flatMap(PlannerMode.init(rawValue:)) ?? .quick,
            createdAt: createdAt
        )
    }
}

/// Fila de `profiles`. El email y si es invitado salen de la sesión de Auth.
struct ProfileRowDTO: Decodable, Sendable {
    let creativeProfiles: [String]
    let sparkHour: String
    let timezone: String
    let locale: String
    let plan: String
    let onboardedAt: Date?
    let creativeRole: String?

    func model(email: String?, isAnonymous: Bool) -> Profile {
        Profile(
            creativeProfiles: creativeProfiles.compactMap(CreativeProfile.init(rawValue:)),
            sparkTime: SparkTime(postgres: sparkHour) ?? .default,
            timezone: timezone,
            locale: locale,
            plan: isAnonymous ? .guest : Plan(rawValue: plan) ?? .free,
            email: isAnonymous ? nil : email,
            isOnboarded: onboardedAt != nil,
            creativeRole: creativeRole
        )
    }
}

/// El perfil ya armado, para la caché.
struct ProfileDTO: Codable, Sendable {
    let creativeProfiles: [String]
    let sparkTime: String
    let timezone: String
    let locale: String
    let plan: String
    let email: String?
    let isOnboarded: Bool
    let creativeRole: String?

    init(_ model: Profile) {
        creativeProfiles = model.creativeProfiles.map(\.rawValue)
        sparkTime = model.sparkTime.postgres
        timezone = model.timezone
        locale = model.locale
        plan = model.plan.rawValue
        email = model.email
        isOnboarded = model.isOnboarded
        creativeRole = model.creativeRole
    }

    var model: Profile {
        Profile(
            creativeProfiles: creativeProfiles.compactMap(CreativeProfile.init(rawValue:)),
            sparkTime: SparkTime(postgres: sparkTime) ?? .default,
            timezone: timezone,
            locale: locale,
            plan: Plan(rawValue: plan) ?? .guest,
            email: email,
            isOnboarded: isOnboarded,
            creativeRole: creativeRole
        )
    }
}

/// `{ "error": "<código>" }` de las Edge Functions.
struct ErrorDTO: Decodable, Sendable {
    let error: String
}

import Foundation
import Testing
@testable import LumbreCore

/// Lo compartido entre la app, la Share Extension, el widget y los App Intents.
@Suite struct ExtensionsTests {
    // MARK: Links profundos

    @Test func deepLinksRoundTrip() throws {
        let id = UUID()
        for link in [LumbreDeepLink.today, .spark(id), .capture(entry: "widget")] {
            #expect(LumbreDeepLink(url: link.url) == link)
        }
        #expect(LumbreDeepLink.spark(id).url.absoluteString == "lumbre://spark/\(id.uuidString.lowercased())")
    }

    @Test func sparkLinkCarriesTheEntryForTheReveal() throws {
        let id = UUID()
        let widget = LumbreDeepLink.spark(id, entry: "widget")
        #expect(widget.url.absoluteString == "lumbre://spark/\(id.uuidString.lowercased())?entry=widget")
        #expect(LumbreDeepLink(url: widget.url) == widget)
        // Va tal cual a `spark_revealed.entry`: solo los valores del plan de analytics.
        #expect(LumbreDeepLink(url: URL(string: "lumbre://spark/\(id.uuidString)?entry=push")!) == .spark(id, entry: "push"))
        #expect(LumbreDeepLink(url: URL(string: "lumbre://spark/\(id.uuidString)?entry=otra")!) == .spark(id))
        #expect(LumbreDeepLink(url: URL(string: "lumbre://spark/\(id.uuidString)")!) == .spark(id))
    }

    @Test func widgetLinksCarryTheSizeForWidgetTapped() throws {
        let id = UUID()
        let spark = LumbreDeepLink.spark(id).widgetURL(size: "small")
        #expect(spark.absoluteString == "lumbre://spark/\(id.uuidString.lowercased())?entry=widget&size=small")
        #expect(LumbreDeepLink(url: spark) == .spark(id, entry: "widget"))
        #expect(LumbreDeepLink.widgetTap(in: spark)?.event == .widgetTapped(action: "open_spark", size: "small"))

        let capture = LumbreDeepLink.capture(entry: "fab").widgetURL(size: "circular")
        #expect(LumbreDeepLink(url: capture) == .capture(entry: "widget"))
        #expect(LumbreDeepLink.widgetTap(in: capture) == .init(action: "capture", size: "circular"))

        // Hoy no está entre las acciones de `widget_tapped`; los links de otro origen tampoco cuentan.
        #expect(LumbreDeepLink(url: LumbreDeepLink.today.widgetURL(size: "medium")) == .today)
        #expect(LumbreDeepLink.widgetTap(in: LumbreDeepLink.today.widgetURL(size: "medium")) == nil)
        #expect(LumbreDeepLink.widgetTap(in: LumbreDeepLink.spark(id, entry: "push").url) == nil)
        #expect(LumbreDeepLink.widgetTap(in: LumbreDeepLink.capture(entry: "widget").url) == nil)
        // El tamaño va tal cual a analytics: solo los conocidos.
        #expect(LumbreDeepLink.widgetTap(in: URL(string: "lumbre://spark/\(id.uuidString)?entry=widget&size=%3Cx%3E")!) == nil)
        #expect(LumbreDeepLink.widgetTap(in: URL(string: "https://lumbre.app/spark/\(id.uuidString)?entry=widget&size=small")!) == nil)
    }

    @Test func deepLinksAreForgiving() throws {
        #expect(LumbreDeepLink(url: URL(string: "lumbre://capture")!) == .capture(entry: "deeplink"))
        #expect(LumbreDeepLink(url: URL(string: "LUMBRE://Today")!) == .today)
        #expect(LumbreDeepLink(url: URL(string: "lumbre://spark/no-es-un-id")!) == .today)
        // El entry va a analytics: nada raro.
        #expect(LumbreDeepLink(url: URL(string: "lumbre://capture?entry=%3Cscript%3E")!) == .capture(entry: "deeplink"))
        #expect(LumbreDeepLink(url: URL(string: "https://lumbre.app/today")!) == nil)
        #expect(LumbreDeepLink(url: URL(string: "lumbre://otra-cosa")!) == nil)
    }

    // MARK: Lo que llega a la Share Extension

    @Test func selectionWithURLKeepsTheFragmentAndTheSource() throws {
        let url = URL(string: "https://example.com/nota")!
        let draft = SharedDraft(text: "  Un ciclón separa sin filtro.  ", url: url, pageTitle: "Ciclones")
        #expect(draft.kind == .selection)
        #expect(draft.suggestedThesis == "Un ciclón separa sin filtro.")
        let request = try #require(draft.request(thesis: "Separar por giro", category: "Ingeniería"))
        #expect(request.source == .selection(url))
        #expect(request.excerpt == "Un ciclón separa sin filtro.")
        #expect(request.sourceTitle == "Ciclones")
        #expect(!request.distill)
    }

    @Test func aLoneURLIsALink() throws {
        let fromText = SharedDraft(text: "https://example.com/a")
        #expect(fromText.kind == .link)
        #expect(fromText.suggestedThesis.isEmpty)
        #expect(fromText.request(thesis: "", category: "Arte") == nil)
        let request = try #require(fromText.request(thesis: "Una idea", category: "Arte"))
        #expect(request.source == .link(URL(string: "https://example.com/a")!))
    }

    @Test func nonWebURLsAreIgnored() {
        let draft = SharedDraft(text: "Hola", url: URL(string: "file:///tmp/x.txt"))
        #expect(draft.kind == .text)
        #expect(SharedDraft(url: URL(string: "otraapp://abrir")).isEmpty)
    }

    @Test func longTextGoesToTheExcerpt() throws {
        let long = String(repeating: "palabra ", count: 120)
        let draft = SharedDraft(text: long)
        #expect(draft.kind == .text)
        #expect(draft.suggestedThesis.isEmpty)
        let request = try #require(draft.request(thesis: "Lo que me deja", category: "Literatura"))
        #expect(request.source == .selection(nil))
        #expect(request.excerpt?.count == SharedDraft.excerptLimit)
    }

    @Test func filesNeedAnIdea() throws {
        let pdf = SharedDraft(pdf: Data([1, 2, 3]), fileName: "paper.pdf")
        #expect(pdf.kind == .pdf)
        #expect(pdf.sourceLabel == "paper.pdf")
        #expect(try #require(pdf.request(thesis: "Idea", category: "Física")).source == .pdf(Data([1, 2, 3])))
        let image = SharedDraft(hasImage: true)
        #expect(image.kind == .image)
        #expect(try #require(image.request(thesis: "Idea", category: "Arte")).source == .screenshot)
        #expect(image.request(thesis: String(repeating: "a", count: 601), category: "Arte") == nil)
    }

    // MARK: Mandar o encolar

    private var directory: URL { FileManager.default.temporaryDirectory.appending(path: "ExternalCapture-\(UUID().uuidString)") }

    @Test func sendsDirectlyWhenItCan() async throws {
        let queue = CaptureQueue(directory: directory)
        let outcome = try await ExternalCapture.submit(CaptureRequest(thesis: "Idea", category: "Arte", source: .text), queue: queue) { _ in
            CaptureResult(conceptID: UUID(), categoryID: UUID(), categoryCreated: false)
        }
        #expect(outcome == .sent)
        #expect(await queue.count == 0)
    }

    @Test func queuesWithoutBackendSessionOrNetwork() async throws {
        let queue = CaptureQueue(directory: directory)
        let request = CaptureRequest(thesis: "Idea", category: "Arte", source: .text)
        #expect(try await ExternalCapture.submit(request, queue: queue, send: nil) == .queued)
        // Sin sesión prestada vigente, SupabaseLumbreAPI responde `.offline`.
        #expect(try await ExternalCapture.submit(request, queue: queue) { _ in throw LumbreAPIError.offline } == .queued)
        #expect(try await ExternalCapture.submit(request, queue: queue) { _ in throw URLError(.timedOut) } == .queued)
        #expect(try await ExternalCapture.submit(request, queue: queue) { _ in throw LumbreAPIError.unexpected } == .queued)
        #expect(await queue.count == 4)
    }

    @Test func validationErrorsAreShownNotQueued() async throws {
        let queue = CaptureQueue(directory: directory)
        let outcome = try await ExternalCapture.submit(CaptureRequest(thesis: "Idea", category: "Arte", source: .text), queue: queue) { _ in
            throw LumbreAPIError.tooManyCategories
        }
        #expect(outcome == .rejected(.tooManyCategories))
        #expect(await queue.count == 0)
    }

    @Test func borrowedSessionWithoutSessionIsOffline() async throws {
        let api = SupabaseLumbreAPI(url: URL(string: "http://127.0.0.1:9")!, publishableKey: "x", devCredentials: nil,
                                    resetSession: false, authStorage: MemoryAuthStorage(), mode: .borrowed)
        await #expect(throws: LumbreAPIError.offline) {
            _ = try await api.capture(CaptureRequest(thesis: "Idea", category: "Arte", source: .text))
        }
    }

    // MARK: Cola compartida entre procesos

    @Test func twoProcessesShareTheQueueWithoutLosingCaptures() async throws {
        let directory = directory
        let app = CaptureQueue(directory: directory)
        try await app.enqueue(CaptureRequest(thesis: "Desde la app", category: "Arte", source: .text))
        // La Share Extension abre su propia instancia y encola mientras la app ya tenía la cola en memoria.
        let shareExtension = CaptureQueue(directory: directory)
        try await shareExtension.enqueue(CaptureRequest(thesis: "Desde Safari", category: "Arte", source: .link(URL(string: "https://example.com")!)))
        #expect(await app.count == 2)

        let sent = SentLog()
        let report = await app.flush { request in
            await sent.append(request.thesis ?? "")
            return CaptureResult(conceptID: UUID(), categoryID: UUID(), categoryCreated: false)
        }
        #expect(report.sent.count == 2)
        #expect(await sent.values == ["Desde la app", "Desde Safari"])
        #expect(await shareExtension.count == 0)
    }

    // MARK: Snapshot del widget

    @Test func snapshotKnowsWhetherItIsToday() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let snapshot = LumbreShared.TodaySnapshot(
            sparkID: UUID(), title: "T", body: "B",
            conceptA: .init(title: "A", category: "Arte"), conceptB: .init(title: "B", category: nil),
            status: .pending, date: now
        )
        #expect(snapshot.isPending)
        #expect(snapshot.isCurrent(at: now.addingTimeInterval(60), calendar: calendar))
        #expect(!snapshot.isCurrent(at: now.addingTimeInterval(86_400 * 2), calendar: calendar))
    }

    @Test func snapshotsWrittenBeforeTheSymbolStillDecode() throws {
        let json = """
        {"sparkID":"\(UUID().uuidString)","title":"T","body":"B","conceptA":{"title":"A","category":"Arte"},
         "conceptB":{"title":"B"},"status":"revealed","date":0}
        """
        let snapshot = try JSONDecoder().decode(LumbreShared.TodaySnapshot.self, from: Data(json.utf8))
        #expect(snapshot.conceptA.symbol == nil)
        #expect(!snapshot.isPending)
    }

    @Test func widgetStateFollowsTheDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 7))!
        let sparkTime = calendar.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 8))!
        let today = calendar.startOfDay(for: morning)
        func snapshot(_ status: SparkStatus, day: Date) -> LumbreShared.TodaySnapshot {
            .init(sparkID: UUID(), title: "T", body: "B", conceptA: .init(title: "A", category: nil),
                  conceptB: .init(title: "B", category: nil), status: status, date: day)
        }
        let revealed = snapshot(.revealed, day: today)
        #expect(TodayWidgetState(snapshot: revealed, nextSparkAt: nil, now: morning, calendar: calendar) == .spark(revealed))
        let pending = snapshot(.pending, day: today)
        #expect(TodayWidgetState(snapshot: pending, nextSparkAt: nil, now: morning, calendar: calendar) == .pending(pending))
        // La de ayer no se muestra como de hoy.
        let yesterday = snapshot(.revealed, day: calendar.date(byAdding: .day, value: -1, to: today)!)
        #expect(TodayWidgetState(snapshot: yesterday, nextSparkAt: sparkTime, now: morning, calendar: calendar) == .waiting(sparkTime))
        #expect(TodayWidgetState(snapshot: yesterday, nextSparkAt: sparkTime, now: sparkTime.addingTimeInterval(60), calendar: calendar) == .ready)
        #expect(TodayWidgetState(snapshot: nil, nextSparkAt: nil, now: morning, calendar: calendar) == .empty)

        let dates = TodayWidgetState.refreshDates(after: morning, nextSparkAt: sparkTime, calendar: calendar)
        #expect(dates == [sparkTime, calendar.date(byAdding: .day, value: 1, to: today)!])
    }

    @Test func storageKeyMatchesSupabase() {
        #expect(SharedKeychain.storageKey(for: URL(string: "https://udewtaksxfnnchuhydnr.supabase.co")!) == "sb-udewtaksxfnnchuhydnr-auth-token")
        #expect(SharedKeychain.storageKey(for: URL(string: "http://127.0.0.1:55521")!) == "sb-127-auth-token")
    }
}

private actor SentLog {
    var values: [String] = []
    func append(_ value: String) { values.append(value) }
}

import Foundation
import Testing
@testable import LumbreCore

@Suite struct CaptureQueueTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "CaptureQueueTests-\(UUID().uuidString)")

    private func makeQueue() -> CaptureQueue {
        CaptureQueue(directory: directory, backoffBase: .milliseconds(10), maxBackoff: .milliseconds(80), maxFailures: 3)
    }

    @Test func enqueuedCapturesSurviveARestart() async throws {
        let queue = makeQueue()
        try await queue.enqueue(CaptureRequest(thesis: "Una idea", category: "Música", source: .voice))
        try await queue.enqueue(CaptureRequest(thesis: "Otra", category: "Cocina", source: .link(URL(string: "https://example.com")!), distill: true))
        #expect(await queue.count == 2)

        let reopened = makeQueue()
        let pending = await reopened.pending
        #expect(pending.count == 2)
        #expect(pending[0].sourceType == .voice)
        #expect(pending[1].sourceURL == URL(string: "https://example.com"))
        #expect(pending[1].distill)
    }

    @Test func attachmentsAreStoredAsSeparateFilesAndRestored() async throws {
        let queue = makeQueue()
        let image = Data(repeating: 7, count: 2048)
        let item = try await queue.enqueue(CaptureRequest(thesis: nil, category: "Arte", source: .image(image), localAssetID: "asset-1", distill: true))
        let file = try #require(item.attachmentFile)
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: file).path()))

        let api = RecordingAPI()
        let report = await makeQueue().flush(send: api.send)
        #expect(report.sent.count == 1)
        let sent = try #require(await api.requests.first)
        #expect(sent.source == .image(image))
        #expect(sent.localAssetID == "asset-1")
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: file).path()))
    }

    @Test func flushSendsInOrderAndEmptiesTheQueue() async throws {
        let queue = makeQueue()
        for index in 1...3 {
            try await queue.enqueue(CaptureRequest(thesis: "Idea \(index)", category: "Historia", source: .text))
        }
        let api = RecordingAPI()
        let report = await queue.flush(send: api.send)
        #expect(report.sent.count == 3)
        #expect(report.remaining == 0)
        #expect(await api.requests.map(\.thesis) == ["Idea 1", "Idea 2", "Idea 3"])
        #expect(await queue.count == 0)
        #expect(await makeQueue().count == 0)
    }

    @Test func networkErrorStopsTheFlushAndKeepsEverything() async throws {
        let queue = makeQueue()
        try await queue.enqueue(CaptureRequest(thesis: "Uno", category: "Arte", source: .text))
        try await queue.enqueue(CaptureRequest(thesis: "Dos", category: "Arte", source: .text))
        let api = RecordingAPI(failures: [URLError(.notConnectedToInternet)])
        let report = await queue.flush(send: api.send)
        #expect(report.sent.isEmpty)
        #expect(report.shouldRetry)
        #expect(await queue.count == 2)

        // Vuelve la red: se reanuda desde donde quedó.
        let resumed = await queue.flush(send: api.send)
        #expect(resumed.sent.count == 2)
        #expect(await queue.count == 0)
    }

    @Test func validationErrorsAreDiscardedAndReported() async throws {
        let queue = makeQueue()
        try await queue.enqueue(CaptureRequest(thesis: "", category: "Arte", source: .text))
        try await queue.enqueue(CaptureRequest(thesis: "Buena", category: "Arte", source: .text))
        let updates = await queue.updates()
        let api = RecordingAPI(failures: [LumbreAPIError.invalidThesis])
        let report = await queue.flush(send: api.send)
        #expect(report.discarded == [.invalidThesis])
        #expect(report.sent.count == 1)
        #expect(await queue.count == 0)

        var received: [CaptureQueue.Update] = []
        for await update in updates {
            received.append(update)
            if received.count == 4 { break }
        }
        #expect(received.contains(.discarded(.invalidThesis)))
        #expect(received.contains(.flushed(sent: 1)))
    }

    @Test func serverErrorsAreRetriedAFewTimesThenDropped() async throws {
        let queue = makeQueue()
        try await queue.enqueue(CaptureRequest(thesis: "Uno", category: "Arte", source: .text))
        let api = RecordingAPI(failures: Array(repeating: LumbreAPIError.unexpected, count: 3))
        #expect(await queue.flush(send: api.send).remaining == 1)
        #expect(await queue.flush(send: api.send).remaining == 1)
        let last = await queue.flush(send: api.send)
        #expect(last.discarded == [.unexpected])
        #expect(await queue.count == 0)
    }

    @Test func quotaErrorsKeepTheCaptureForLater() async throws {
        let queue = makeQueue()
        try await queue.enqueue(CaptureRequest(thesis: "Uno", category: "Arte", source: .text))
        let report = await queue.flush(send: RecordingAPI(failures: [LumbreAPIError.quotaExceeded]).send)
        #expect(report.shouldRetry)
        #expect(await queue.count == 1)
    }

    @Test func monitoringFlushesOnItsOwnWithBackoff() async throws {
        let queue = makeQueue()
        try await queue.enqueue(CaptureRequest(thesis: "Uno", category: "Arte", source: .text))
        let api = RecordingAPI(failures: [URLError(.timedOut), URLError(.timedOut)])
        let updates = await queue.updates()
        await queue.startMonitoring(send: api.send)
        for await update in updates where update == .count(0) { break }
        #expect(await api.attempts == 3)
        await queue.stopMonitoring()
    }

    @Test func flushWorksAgainstTheMockBackend() async throws {
        let queue = makeQueue()
        let api = MockLumbreAPI(latency: .zero)
        try await queue.enqueue(CaptureRequest(thesis: "Guardada sin red", category: "Astronomía", source: .voice))
        let report = await queue.flush(using: api)
        let result = try #require(report.sent.first)
        #expect(result.categoryCreated)
        #expect(try await api.concepts().contains { $0.id == result.conceptID })
        #expect(await queue.count == 0)
    }

    @Test func backoffDoublesUpToTheCap() {
        let queue = makeQueue()
        #expect(queue.backoff(attempt: 1) == .milliseconds(10))
        #expect(queue.backoff(attempt: 2) == .milliseconds(20))
        #expect(queue.backoff(attempt: 4) == .milliseconds(80))
        #expect(queue.backoff(attempt: 9) == .milliseconds(80))
    }

    @Test func connectivityErrorsAreRecognized() {
        #expect(CaptureQueue.isConnectivityError(LumbreAPIError.offline))
        #expect(CaptureQueue.isConnectivityError(URLError(.networkConnectionLost)))
        let wrapped = NSError(domain: "Supabase", code: 1, userInfo: [NSUnderlyingErrorKey: URLError(.notConnectedToInternet) as NSError])
        #expect(CaptureQueue.isConnectivityError(wrapped))
        #expect(!CaptureQueue.isConnectivityError(LumbreAPIError.invalidThesis))
        #expect(!CaptureQueue.isConnectivityError(URLError(.badServerResponse)))
    }
}

/// Backend de prueba: falla con los errores dados (en orden) y después guarda lo que recibe.
private actor RecordingAPI {
    var failures: [Error]
    var requests: [CaptureRequest] = []
    var attempts = 0

    init(failures: [Error] = []) {
        self.failures = failures
    }

    func capture(_ request: CaptureRequest) throws -> CaptureResult {
        attempts += 1
        if !failures.isEmpty { throw failures.removeFirst() }
        if request.thesis?.isEmpty == true { throw LumbreAPIError.invalidThesis }
        requests.append(request)
        return CaptureResult(conceptID: UUID(), categoryID: UUID(), categoryCreated: false)
    }

    nonisolated var send: CaptureQueue.Sender {
        { try await self.capture($0) }
    }
}

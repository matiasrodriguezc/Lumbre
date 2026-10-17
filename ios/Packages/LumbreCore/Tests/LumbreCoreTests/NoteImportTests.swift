import Foundation
import Testing
@testable import LumbreCore

@Suite struct NoteImportTests {
    // MARK: Markdown

    @Test func headingOnTheFirstLineIsTheThesis() throws {
        let note = try #require(NoteImport.markdown("""
        # Separación ciclónica

        Un flujo en **espiral** separa partículas por [fuerza centrífuga](https://example.com), sin filtro.
        - Sirve para el polvo
        """, fileName: "Ciclones.md"))
        #expect(note.thesis == "Separación ciclónica")
        #expect(note.excerpt == "Un flujo en espiral separa partículas por fuerza centrífuga, sin filtro.\nSirve para el polvo")
        #expect(note.source == .markdown)
    }

    @Test func frontMatterTitleWinsAndFrontMatterIsDropped() throws {
        let note = try #require(NoteImport.markdown("""
        ---
        title: "Ritmo y repetición"
        tags: [musica]
        ---
        # Ritmo y repetición
        La repetición crea expectativa.
        """, fileName: "2026-10-17.md"))
        #expect(note.thesis == "Ritmo y repetición")
        #expect(note.excerpt == "La repetición crea expectativa.")
    }

    @Test func fileNameIsTheThesisWhenThereIsNoHeading() throws {
        let note = try #require(NoteImport.markdown("Las hormigas no tienen jefe.\n\nCada una sigue reglas locales.", fileName: "Inteligencia de enjambre.md"))
        #expect(note.thesis == "Inteligencia de enjambre")
        #expect(note.excerpt == "Las hormigas no tienen jefe.\nCada una sigue reglas locales.")
    }

    @Test func genericFileNamesFallBackToTheFirstLine() throws {
        for name in ["Untitled.md", "Untitled 3.md", "Sin título.md", "2026-10-17.md", "20261017.md"] {
            let note = try #require(NoteImport.markdown("\n\nEl [[pan de masa madre|pan]] necesita tiempo.\nY paciencia.", fileName: name))
            #expect(note.thesis == "El pan necesita tiempo.", "\(name)")
            #expect(note.excerpt == "Y paciencia.")
        }
    }

    @Test func fileNameRepeatedAsFirstLineIsNotDuplicated() throws {
        let note = try #require(NoteImport.markdown("Idea suelta\nEl resto.", fileName: "Idea suelta.md"))
        #expect(note.thesis == "Idea suelta")
        #expect(note.excerpt == "El resto.")
    }

    @Test func markdownSyntaxIsRemoved() {
        let lines = NoteImport.cleanBody([
            "> [!note] Un callout",
            "- [x] tarea hecha",
            "1. primero",
            "```swift",
            "let x = 1",
            "```",
            "---",
            "Texto con `código`, *itálica*, _otra_, ~~tachado~~, ==resaltado== y ![img](a.png)![[foto.png]]",
            "snake_case_queda <b>sin</b> tocar",
        ])
        #expect(lines == [
            "Un callout", "tarea hecha", "primero", "let x = 1",
            "Texto con código, itálica, otra, tachado, resaltado y",
            "snake_case_queda sin tocar",
        ])
    }

    @Test func commentsAreDroppedEvenAcrossLines() throws {
        let note = try #require(NoteImport.markdown("%% privado\nno va %%\n# Título\n<!-- tampoco -->Queda esto", fileName: nil))
        #expect(note.thesis == "Título")
        #expect(note.excerpt == "Queda esto")
    }

    @Test func emptyNotesAreSkipped() {
        #expect(NoteImport.markdown("---\ntags: []\n---\n\n   \n", fileName: "Untitled.md") == nil)
        #expect(NoteImport.markdown("", fileName: nil) == nil)
        #expect(NoteImport.plainNote("  \n\n ") == nil)
    }

    @Test func longTextIsCutOnAWordWithinTheLimits() throws {
        let long = Array(repeating: "palabra", count: 200).joined(separator: " ")
        let note = try #require(NoteImport.markdown("\(long)\n\(long)", fileName: nil))
        #expect(note.thesis.count <= NoteImport.thesisLimit)
        #expect(note.thesis.hasSuffix("palabra…"))
        let excerpt = try #require(note.excerpt)
        #expect(excerpt.count <= NoteImport.excerptLimit)
        #expect(excerpt.hasSuffix("…"))
    }

    // MARK: Apple Notes

    @Test func appleNoteUsesItsFirstLine() throws {
        let note = try #require(NoteImport.plainNote("\n  Lista de regalos  \nUn libro\n\nUna planta", folder: "Personal"))
        #expect(note.thesis == "Lista de regalos")
        #expect(note.excerpt == "Un libro\nUna planta")
        #expect(note.folder == "Personal")
        #expect(note.source == .appleNotes)
    }

    // MARK: Archivos y carpetas

    @Test func folderScanSkipsHiddenFoldersAndUsesTheTopFolderAsCategory() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "Vault-\(UUID().uuidString)")
        let files: [String: String] = [
            "Bienvenida.md": "# Bienvenida\nEmpezá acá.",
            "Biología/Enjambres.md": "Las hormigas no tienen jefe.",
            "Biología/Profundo/Micelio.md": "# Micelio\nUna red bajo tierra.",
            "Cocina/Untitled.md": "",
            ".obsidian/workspace.md": "# No va",
            ".trash/Borrada.md": "# Tampoco",
            "Adjuntos/foto.png": "no es markdown",
        ]
        for (path, text) in files {
            let url = root.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        defer { try? FileManager.default.removeItem(at: root) }

        let scan = NoteImport.readFolder(root)
        #expect(scan.notes.map(\.thesis) == ["Bienvenida", "Enjambres", "Micelio"])
        #expect(scan.notes.map(\.folder) == [nil, "Biología", "Biología"])
        #expect(scan.skippedEmpty == 1)
        #expect(!scan.truncated)
    }

    @Test func looseFilesAreReadWithoutFolder() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "Loose-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var urls: [URL] = []
        for (name, text) in [("Uno.md", "Primera idea"), ("Dos.md", "# Segunda\nCon cuerpo"), ("Grande.md", String(repeating: "x", count: NoteImport.maxFileBytes + 1))] {
            let url = directory.appending(path: name)
            try text.write(to: url, atomically: true, encoding: .utf8)
            urls.append(url)
        }
        let scan = NoteImport.readFiles(urls)
        #expect(scan.notes.map(\.thesis) == ["Uno", "Segunda"])
        #expect(scan.notes.allSatisfy { $0.folder == nil })
        #expect(scan.skippedUnreadable == 1)
    }

    // MARK: Tanda

    @Test func batchGroupsByFolderAndBuildsImportRequests() throws {
        let notes = [
            ImportNote(source: .markdown, thesis: "Suelta", excerpt: nil, folder: nil),
            ImportNote(source: .markdown, thesis: "Enjambres", excerpt: "Sin jefe", folder: "Biología"),
            ImportNote(source: .markdown, thesis: "Pan", excerpt: nil, folder: "Cocina"),
        ]
        var batch = ImportBatch(notes: notes, fallbackCategory: "Notas")
        #expect(batch.groups.map(\.id) == ["", "Biología", "Cocina"])
        #expect(batch.groups.map(\.category) == ["Notas", "Biología", "Cocina"])
        #expect(batch.selected.count == 3)

        batch.setCategory("  Gastronomía  ", forGroup: "Cocina")
        batch.toggle(notes[0].id)
        let requests = batch.requests()
        #expect(requests.map(\.thesis) == ["Enjambres", "Pan"])
        #expect(requests.map(\.category) == ["Biología", "Gastronomía"])
        #expect(requests.allSatisfy { $0.importSource == .markdown && $0.source == .text && !$0.distill })
        #expect(requests[0].excerpt == "Sin jefe")
        #expect(batch.categories == ["Biología", "Gastronomía"])

        batch.setAll(false, inGroup: "Biología")
        #expect(batch.selectedNotes.map(\.thesis) == ["Pan"])
        batch.setAll(true)
        #expect(batch.selected.count == 3)
    }

    @Test func alreadyImportedAndRepeatedNotesStartUnselected() {
        let old = ImportNote(source: .markdown, thesis: "Vieja", excerpt: nil, folder: nil)
        let new = ImportNote(source: .markdown, thesis: "Nueva", excerpt: nil, folder: nil)
        let copy = ImportNote(source: .markdown, thesis: "nueva", excerpt: nil, folder: nil)
        let batch = ImportBatch(notes: [old, new, copy], fallbackCategory: "Notas", history: [old.fingerprint])
        #expect(batch.alreadyImported == [old.id])
        #expect(batch.selected == [new.id])
    }

    @Test func historyRemembersFingerprintsOnly() throws {
        let defaults = try #require(UserDefaults(suiteName: "NoteImportTests-\(UUID().uuidString)"))
        let history = ImportHistory(defaults: defaults)
        let note = ImportNote(source: .appleNotes, thesis: "Secreta", excerpt: "texto", folder: nil)
        history.record([note, note])
        #expect(history.fingerprints == [note.fingerprint])
        #expect(!(defaults.stringArray(forKey: "importedNoteFingerprints") ?? []).contains { $0.contains("Secreta") })
        history.clear()
        #expect(history.fingerprints.isEmpty)
    }

    @Test func batchLimitDependsOnPlan() {
        #expect(NoteImport.batchLimit(plan: .free, remaining: 38) == 38)
        #expect(NoteImport.batchLimit(plan: .guest, remaining: nil) == 50)
        #expect(NoteImport.batchLimit(plan: .free, remaining: -1) == 0)
        #expect(NoteImport.batchLimit(plan: .pro, remaining: 1000) == NoteImport.proBatchLimit)
        #expect(NoteImport.batchLimit(plan: .pro, remaining: 120) == 120)
    }

    // MARK: Buzón y cola

    @Test func inboxKeepsNotesUntilTaken() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "Inbox-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try #require(NoteImport.plainNote("Uno\ncuerpo"))
        let second = try #require(NoteImport.plainNote("Dos"))
        try ImportInbox.post([first], directory: directory)
        try ImportInbox.post([second], directory: directory)
        #expect(ImportInbox.peek(directory: directory).map(\.thesis) == ["Uno", "Dos"])
        #expect(ImportInbox.take(directory: directory) == [first, second])
        #expect(ImportInbox.take(directory: directory).isEmpty)
    }

    @Test func importedCapturesGoThroughTheQueueAndKeepTheirSource() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ImportQueue-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let queue = CaptureQueue(directory: directory, backoffBase: .milliseconds(10))
        let batch = ImportBatch(notes: [
            ImportNote(source: .appleNotes, thesis: "Una", excerpt: "cuerpo", folder: nil),
            ImportNote(source: .appleNotes, thesis: "Otra", excerpt: nil, folder: nil),
        ], fallbackCategory: "Notas")
        try await queue.enqueue(contentsOf: batch.requests())

        // Sobrevive a un reinicio con su origen.
        let reopened = CaptureQueue(directory: directory)
        #expect(await reopened.pending.map(\.importSource) == [.appleNotes, .appleNotes])

        let sent = SentRequests()
        let report = await reopened.flush(send: { request in
            await sent.append(request)
            if request.thesis == "Otra" { throw LumbreAPIError.importLimitReached }
            return CaptureResult(conceptID: UUID(), categoryID: UUID(), categoryCreated: false)
        })
        #expect(report.sent.count == 1)
        // Sin cupo de importación no se reintenta: se descarta y se avisa.
        #expect(report.discarded == [.importLimitReached])
        #expect(report.remaining == 0)
        let requests = await sent.requests
        #expect(requests.map(\.importSource) == [.appleNotes, .appleNotes])
        #expect(requests[0].excerpt == "cuerpo")
    }

    @Test func importNeverRequestsDistillation() {
        let request = CaptureRequest(thesis: "x", category: "y", source: .text, distill: true, importSource: .markdown)
        #expect(!request.distill)
    }

    @Test func captureBodySendsTheImportSource() throws {
        let body = CaptureBody(NoteImport.request(for: ImportNote(source: .appleNotes, thesis: "Hola", excerpt: nil, folder: nil), category: "Notas"), attachment: nil)
        let json = try #require(try JSONSerialization.jsonObject(with: LumbreJSON.encoder().encode(body)) as? [String: Any])
        #expect(json["import_source"] as? String == "apple_notes")
        #expect(json["distill"] as? Bool == false)
        let plain = CaptureBody(CaptureRequest(thesis: "Hola", category: "Notas", source: .text), attachment: nil)
        let plainJSON = try #require(try JSONSerialization.jsonObject(with: LumbreJSON.encoder().encode(plain)) as? [String: Any])
        #expect(plainJSON["import_source"] == nil || plainJSON["import_source"] is NSNull)
    }

    @Test func importLimitErrorIsTranslated() {
        #expect(LumbreAPIError(serverMessage: "import_limit") == .importLimitReached)
        #expect(CaptureQueue.classify(LumbreAPIError.importLimitReached) == .rejected(.importLimitReached))
    }
}

private actor SentRequests {
    var requests: [CaptureRequest] = []
    func append(_ request: CaptureRequest) { requests.append(request) }
}

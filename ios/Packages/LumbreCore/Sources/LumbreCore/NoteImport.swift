import CryptoKit
import Foundation

// Importar notas (paso 89, flag `import_notes`): archivos Markdown sueltos, una carpeta de Obsidian o las notas
// de Apple Notes que manda un atajo. Cada nota entra como una neurona por `/capture` y la cola offline:
// - Las largas (30 palabras o más) se conceptualizan con IA si hay cupo y "Acepto" (decidido el 2026-10-17).
// - Si no, la tesis es el título o la primera línea no vacía (editable en la vista previa) y el resto queda como fragmento.
// - Cuentan para el tope de capturas del día: lo que pasa del tope sigue mañana desde la cola.
// El texto de las notas es contenido del usuario: se trata como datos y nunca va al log.

/// De dónde viene una nota importada (`concepts.import_source`).
public enum ImportSource: String, Sendable, Codable, CaseIterable {
    case markdown
    case appleNotes = "apple_notes"
}

/// Una nota lista para importar.
public struct ImportNote: Sendable, Identifiable, Hashable, Codable {
    public let id: UUID
    public let source: ImportSource
    /// La tesis: el título o la primera línea no vacía, hasta 600 caracteres.
    public let thesis: String
    /// El resto de la nota, hasta 500 caracteres (va como fragmento).
    public let excerpt: String?
    /// La nota entera en texto plano (título y cuerpo, hasta `NoteImport.noteTextLimit`), para conceptualizarla.
    public let text: String
    /// Palabras de la nota entera: con 30 o más se puede conceptualizar.
    public let words: Int
    /// Carpeta de origen (la de primer nivel en Obsidian, o la que pasa el atajo). Sugiere la categoría.
    public let folder: String?
    /// Huella para reconocer una nota que ya se importó en este teléfono.
    public let fingerprint: String

    public init(id: UUID = UUID(), source: ImportSource, thesis: String, excerpt: String?, folder: String?, text: String? = nil) {
        self.id = id
        self.source = source
        self.thesis = thesis
        self.excerpt = excerpt
        self.folder = folder
        let text = text ?? [thesis, excerpt].compactMap { $0 }.joined(separator: "\n")
        self.text = String(text.prefix(NoteImport.noteTextLimit))
        words = text.split(whereSeparator: \.isWhitespace).count
        fingerprint = NoteImport.fingerprint(thesis: thesis, excerpt: excerpt)
    }

    /// Larga: con conceptualización, Lumbre saca la idea de la nota entera (el mismo umbral que `/capture`).
    public var isLong: Bool { words >= NoteImport.distillMinWords }
}

/// Lo que salió de leer archivos o una carpeta.
public struct ImportScan: Sendable, Equatable {
    public var notes: [ImportNote] = []
    /// Archivos o notas sin texto.
    public var skippedEmpty = 0
    /// Archivos de más de `NoteImport.maxFileBytes`, o que no se pudieron leer.
    public var skippedUnreadable = 0
    /// La carpeta tenía más de `NoteImport.maxFiles` notas: se leyeron las primeras.
    public var truncated = false

    public init() {}
}

public enum NoteImport {
    /// Tope de la tesis (el mismo de `capture_concept()`).
    public static let thesisLimit = SharedDraft.thesisLimit
    /// Tope del fragmento (el mismo de `capture_concept()`).
    public static let excerptLimit = 500
    /// Lo que se manda de la nota entera para conceptualizar (`/capture` acepta hasta 20.000 y lee 2.500 palabras).
    public static let noteTextLimit = 20_000
    /// Desde cuántas palabras una nota se conceptualiza (igual que `/capture`).
    public static let distillMinWords = 30
    /// Notas que se pueden importar en free y como invitado, en total (`plan_limits`, kind `import`).
    public static let freeLimit = 50
    /// Tope técnico por tanda en Pro (provisorio: ver ios/README.md). Pro no tiene cupo de importación, pero cada
    /// nota cuenta como captura (200 por día): una tanda de 500 tarda tres días en entrar.
    public static let proBatchLimit = 500
    /// Un archivo más grande que esto no es una nota: se saltea.
    public static let maxFileBytes = 1_000_000
    /// Archivos que se leen como mucho de una carpeta.
    public static let maxFiles = 5_000
    /// Notas que acepta el App Intent por vez.
    public static let maxIntentNotes = 1_000

    static let markdownExtensions: Set<String> = ["md", "markdown"]

    // MARK: - Una nota

    /// Una nota de Markdown. La tesis sale, en este orden, del `title` del front matter, de un título en la primera
    /// línea (`# …`), del nombre del archivo (si no es genérico, como "Untitled" o una fecha) o de la primera línea no vacía.
    public static func markdown(_ text: String, fileName: String?, folder: String? = nil) -> ImportNote? {
        var (frontMatterTitle, lines) = splitFrontMatter(normalizeNewlines(text))
        lines = removeComments(lines)

        var title = frontMatterTitle.map(cleanInline).flatMap(nonEmpty)
        if let index = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            let first = lines[index]
            if let heading = headingText(first) {
                // Un título en la primera línea manda sobre el nombre del archivo, salvo que el front matter ya traiga uno.
                if title == nil { title = nonEmpty(cleanInline(heading)) }
                if title != nil { lines.remove(at: index) }
            }
        }
        if title == nil, let name = fileName.map(stripExtension), !isGenericName(name) {
            title = nonEmpty(cleanInline(name))
        }

        var body = cleanBody(lines)
        if let current = title, let first = body.first, first.caseInsensitiveCompare(current) == .orderedSame {
            // El nombre del archivo repetido como primera línea.
            body.removeFirst()
        }
        if title == nil, !body.isEmpty {
            title = body.removeFirst()
        }
        guard let title else { return nil }
        return makeNote(source: .markdown, title: title, body: body, folder: folder)
    }

    /// Una nota de texto plano (Apple Notes vía Atajos): la primera línea no vacía es el título.
    public static func plainNote(_ text: String, folder: String? = nil, source: ImportSource = .appleNotes) -> ImportNote? {
        var body = normalizeNewlines(text)
            .components(separatedBy: "\n")
            .map { collapseSpaces($0) }
            .filter { !$0.isEmpty }
        guard !body.isEmpty else { return nil }
        let title = body.removeFirst()
        return makeNote(source: source, title: title, body: body, folder: folder)
    }

    private static func makeNote(source: ImportSource, title: String, body: [String], folder: String?) -> ImportNote? {
        let thesis = truncate(collapseSpaces(title), to: thesisLimit)
        guard !thesis.isEmpty else { return nil }
        let joined = body.joined(separator: "\n")
        let excerpt = nonEmpty(truncate(joined, to: excerptLimit))
        let text = joined.isEmpty ? collapseSpaces(title) : collapseSpaces(title) + "\n" + joined
        return ImportNote(source: source, thesis: thesis, excerpt: excerpt, folder: folder.flatMap(categoryName), text: text)
    }

    // MARK: - Archivos y carpetas

    /// Lee archivos `.md` sueltos (los que se eligieron en Archivos).
    public static func readFiles(_ urls: [URL]) -> ImportScan {
        var scan = ImportScan()
        for url in urls.prefix(maxFiles) {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            add(url, folder: nil, to: &scan)
        }
        scan.truncated = urls.count > maxFiles
        return scan
    }

    /// Lee una carpeta (por ejemplo, una bóveda de Obsidian) con sus subcarpetas. Saltea lo oculto (`.obsidian`,
    /// `.trash`) y lo que no es Markdown. La carpeta de primer nivel de cada nota sugiere su categoría.
    public static func readFolder(_ root: URL) -> ImportScan {
        let scoped = root.startAccessingSecurityScopedResource()
        defer { if scoped { root.stopAccessingSecurityScopedResource() } }
        var scan = ImportScan()
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return scan
        }
        let rootComponents = root.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        var files: [(url: URL, relative: [String])] = []
        for case let url as URL in enumerator {
            guard markdownExtensions.contains(url.pathExtension.lowercased()),
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            let components = url.standardizedFileURL.resolvingSymlinksInPath().pathComponents
            let relative = Array(components.dropFirst(rootComponents.count))
            files.append((url, relative.isEmpty ? [url.lastPathComponent] : relative))
            if files.count > maxFiles { break }
        }
        files.sort { $0.relative.joined(separator: "/").localizedStandardCompare($1.relative.joined(separator: "/")) == .orderedAscending }
        scan.truncated = files.count > maxFiles
        for file in files.prefix(maxFiles) {
            add(file.url, folder: file.relative.count > 1 ? file.relative[0] : nil, to: &scan)
        }
        return scan
    }

    private static func add(_ url: URL, folder: String?, to scan: inout ImportScan) {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= maxFileBytes, let data = try? Data(contentsOf: url) else {
            scan.skippedUnreadable += 1
            return
        }
        let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        if let note = markdown(text, fileName: url.lastPathComponent, folder: folder) {
            scan.notes.append(note)
        } else {
            scan.skippedEmpty += 1
        }
    }

    // MARK: - Categorías y pedidos

    /// Nombre de categoría válido (1 a 40 caracteres) a partir de una carpeta, o nil.
    public static func categoryName(_ folder: String) -> String? {
        let name = collapseSpaces(folder.replacingOccurrences(of: "_", with: " "))
        guard !name.isEmpty else { return nil }
        return String(name.prefix(40)).trimmingCharacters(in: .whitespaces)
    }

    /// El pedido de `/capture` de una nota importada. Con `distill`, el servidor saca la idea de la nota entera y,
    /// si no puede (o no hay cupo), la guarda con `thesis`.
    public static func request(for note: ImportNote, category: String, thesis: String? = nil, distill: Bool = false) -> CaptureRequest {
        CaptureRequest(thesis: thesis ?? note.thesis, category: category, source: .text, excerpt: note.excerpt,
                       distill: distill && note.isLong, importSource: note.source, noteText: note.text)
    }

    /// Cuántas notas se pueden importar en esta tanda: lo que queda del cupo (free e invitado) o el tope por tanda (Pro).
    public static func batchLimit(plan: Plan, remaining: Int?) -> Int {
        switch plan {
        case .pro: min(proBatchLimit, remaining ?? proBatchLimit)
        case .free, .guest: max(0, min(freeLimit, remaining ?? freeLimit))
        }
    }

    // MARK: - Limpieza del Markdown

    static func normalizeNewlines(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    /// Saca el front matter (`---` … `---` al principio) y devuelve su `title`, si tiene.
    static func splitFrontMatter(_ text: String) -> (title: String?, lines: [String]) {
        var lines = text.components(separatedBy: "\n")
        if let first = lines.first, first.hasPrefix("\u{FEFF}") { lines[0] = String(first.dropFirst()) }
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
              let end = lines.dropFirst().firstIndex(where: { ["---", "..."].contains($0.trimmingCharacters(in: .whitespaces)) }) else {
            return (nil, lines)
        }
        var title: String?
        for line in lines[1..<end] {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces).lowercased() == "title" else { continue }
            let value = parts[1].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            title = value.isEmpty ? nil : value
        }
        return (title, Array(lines[(end + 1)...]))
    }

    /// Saca los comentarios de Obsidian (`%% … %%`) y de HTML (`<!-- … -->`), también los de varias líneas.
    static func removeComments(_ lines: [String]) -> [String] {
        var text = lines.joined(separator: "\n")
        for pattern in ["%%[\\s\\S]*?%%", "<!--[\\s\\S]*?-->"] {
            text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return text.components(separatedBy: "\n")
    }

    /// El texto de un título de Markdown (`# Algo` → "Algo"), o nil si la línea no es un título.
    static func headingText(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let range = trimmed.range(of: "^#{1,6}\\s+", options: .regularExpression) else { return nil }
        let text = trimmed[range.upperBound...].replacingOccurrences(of: "\\s+#+\\s*$", with: "", options: .regularExpression)
        return text.isEmpty ? nil : text
    }

    /// Las líneas del cuerpo en texto plano, sin vacías, sin cercas de código ni separadores.
    static func cleanBody(_ lines: [String]) -> [String] {
        lines.compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { return nil }
            if trimmed.range(of: "^([-*_]\\s*){3,}$", options: .regularExpression) != nil { return nil }
            var text = trimmed
            for pattern in [
                "^#{1,6}\\s+",                 // títulos
                "^(>\\s?)+",                    // citas
                "^\\[![^\\]]*\\][+-]?\\s*",     // callouts de Obsidian, después de la cita
                "^[-*+]\\s+\\[[ xX]\\]\\s+",    // tareas
                "^[-*+]\\s+",                   // viñetas
                "^\\d+[.)]\\s+",                // listas numeradas
            ] {
                text = text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            }
            return nonEmpty(cleanInline(text))
        }
    }

    /// Saca la sintaxis de Markdown de una línea: imágenes, links, wikilinks, énfasis, código y HTML.
    static func cleanInline(_ line: String) -> String {
        var text = line
        let replacements: [(String, String)] = [
            ("!\\[\\[[^\\]]*\\]\\]", ""),                       // embebidos de Obsidian
            ("!\\[[^\\]]*\\]\\([^)]*\\)", ""),                  // imágenes
            ("\\[\\[[^\\]|]*\\|([^\\]]*)\\]\\]", "$1"),         // [[nota|alias]]
            ("\\[\\[([^\\]]*)\\]\\]", "$1"),                    // [[nota]]
            ("\\[([^\\]]*)\\]\\([^)]*\\)", "$1"),               // [texto](url)
            ("<[^>\\n]+>", ""),                                 // HTML
            ("`+([^`]*)`+", "$1"),                              // código
            ("(\\*\\*|__|~~|==)(.+?)\\1", "$2"),                // negrita, tachado, resaltado
            ("(?<![\\w*])\\*(?!\\s)([^*\\n]+?)\\*(?![\\w*])", "$1"), // *itálica*
            ("(?<![\\w_])_(?!\\s)([^_\\n]+?)_(?![\\w_])", "$1"),    // _itálica_
        ]
        for (pattern, template) in replacements {
            text = text.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        return collapseSpaces(text)
    }

    /// "Untitled 2", "Sin título", "Nueva nota", una fecha o solo números: no sirven como tesis.
    static func isGenericName(_ name: String) -> Bool {
        let lowered = collapseSpaces(name).lowercased()
        if lowered.isEmpty { return true }
        let generic = ["untitled", "sin título", "sin titulo", "nueva nota", "new note", "nota", "note", "untitled note"]
        if generic.contains(where: { lowered == $0 || lowered.range(of: "^\($0) \\d+$", options: .regularExpression) != nil }) { return true }
        // Fechas y números sueltos (notas diarias: 2026-10-17, 20261017, 17-10-2026).
        return lowered.range(of: "^[\\d\\s._-]+$", options: .regularExpression) != nil
    }

    static func stripExtension(_ fileName: String) -> String {
        let url = URL(fileURLWithPath: fileName)
        return markdownExtensions.contains(url.pathExtension.lowercased()) || url.pathExtension.lowercased() == "txt"
            ? url.deletingPathExtension().lastPathComponent
            : fileName
    }

    static func collapseSpaces(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
    }

    /// Corta en la última palabra entera que entra y agrega "…".
    static func truncate(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        let head = String(text.prefix(limit - 1))
        let cut = head.range(of: "\\s\\S*$", options: .regularExpression).map { String(head[..<$0.lowerBound]) } ?? head
        return (cut.isEmpty ? head : cut).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func fingerprint(thesis: String, excerpt: String?) -> String {
        let normalized = (thesis + "\n" + (excerpt ?? "")).lowercased()
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.prefix(12).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Vista previa

/// La tanda que se está por importar: qué notas van y en qué categoría cae cada grupo.
/// Las notas se agrupan por carpeta de origen; las que no tienen carpeta van a `fallbackCategory`.
public struct ImportBatch: Sendable, Equatable {
    public struct Group: Sendable, Identifiable, Equatable {
        /// La carpeta de origen, o "" para las notas sueltas.
        public let id: String
        public let category: String
        public let notes: [ImportNote]
    }

    public let notes: [ImportNote]
    public var selected: Set<ImportNote.ID>
    /// Notas que ya se importaron en este teléfono (arrancan sin elegir).
    public let alreadyImported: Set<ImportNote.ID>
    public var fallbackCategory: String
    /// Categoría elegida para cada grupo, si se cambió.
    public var categoryOverrides: [String: String] = [:]
    /// Tesis editadas en la vista previa.
    public var thesisOverrides: [ImportNote.ID: String] = [:]
    /// Conceptualizar las notas largas (con el "Acepto"; se puede apagar para no gastar el cupo).
    public var distillLongNotes = false
    /// Cuántas conceptualizaciones quedan este mes: solo esas notas largas se mandan a conceptualizar.
    public var distillAllowance = 0

    public init(notes: [ImportNote], fallbackCategory: String, history: Set<String> = []) {
        self.notes = notes
        self.fallbackCategory = fallbackCategory
        alreadyImported = Set(notes.filter { history.contains($0.fingerprint) }.map(\.id))
        // Las repetidas dentro de la misma tanda tampoco se eligen dos veces.
        var seen = Set<String>()
        var selected = Set<ImportNote.ID>()
        for note in notes where !history.contains(note.fingerprint) && seen.insert(note.fingerprint).inserted {
            selected.insert(note.id)
        }
        self.selected = selected
    }

    public func category(forGroup id: String) -> String {
        categoryOverrides[id] ?? (id.isEmpty ? fallbackCategory : id)
    }

    public var groups: [Group] {
        var order: [String] = []
        var byGroup: [String: [ImportNote]] = [:]
        for note in notes {
            let key = note.folder ?? ""
            if byGroup[key] == nil { order.append(key) }
            byGroup[key, default: []].append(note)
        }
        // Las sueltas primero; las carpetas, en el orden en que aparecieron.
        order.sort { $0.isEmpty && !$1.isEmpty }
        return order.map { Group(id: $0, category: category(forGroup: $0), notes: byGroup[$0] ?? []) }
    }

    public var selectedNotes: [ImportNote] { notes.filter { selected.contains($0.id) } }

    /// La tesis con la que entra la nota si no se conceptualiza.
    public func thesis(for note: ImportNote) -> String {
        thesisOverrides[note.id] ?? note.thesis
    }

    /// Edita la tesis (1 a 600 caracteres). Vacía, vuelve a la original.
    public mutating func setThesis(_ text: String, for id: ImportNote.ID) {
        let thesis = NoteImport.collapseSpaces(text)
        thesisOverrides[id] = thesis.isEmpty ? nil : String(thesis.prefix(NoteImport.thesisLimit))
    }

    /// Las notas elegidas que se mandan a conceptualizar: las largas, en orden, hasta lo que queda del cupo.
    public var distilledIDs: Set<ImportNote.ID> {
        guard distillLongNotes else { return [] }
        return Set(selectedNotes.filter(\.isLong).prefix(max(0, distillAllowance)).map(\.id))
    }

    /// Notas largas elegidas que no entran en el cupo de conceptualización: van con su primera línea.
    public var longNotesWithoutDistill: Int {
        selectedNotes.filter(\.isLong).count - distilledIDs.count
    }

    public mutating func toggle(_ id: ImportNote.ID) {
        if selected.contains(id) { selected.remove(id) } else { selected.insert(id) }
    }

    public mutating func setCategory(_ name: String, forGroup id: String) {
        guard let category = NoteImport.categoryName(name) else { return }
        if id.isEmpty { fallbackCategory = category }
        categoryOverrides[id] = category
    }

    /// Selecciona todas (o ninguna) las notas de un grupo; nil, todas las de la tanda.
    public mutating func setAll(_ isSelected: Bool, inGroup id: String? = nil) {
        let ids = notes.filter { id == nil || ($0.folder ?? "") == id }.map(\.id)
        if isSelected { selected.formUnion(ids) } else { selected.subtract(ids) }
    }

    /// Categorías distintas que va a usar la tanda.
    public var categories: Set<String> {
        Set(selectedNotes.map { category(forGroup: $0.folder ?? "") })
    }

    /// Los pedidos de `/capture`, en el orden de las notas.
    public func requests() -> [CaptureRequest] {
        let distilled = distilledIDs
        return selectedNotes.map {
            NoteImport.request(for: $0, category: category(forGroup: $0.folder ?? ""), thesis: thesis(for: $0), distill: distilled.contains($0.id))
        }
    }
}

// MARK: - Historial y buzón

/// Huellas de las notas ya importadas en este teléfono, para no gastar el cupo dos veces en la misma nota.
/// Solo guarda hashes, nunca el texto. Se borra al cerrar sesión.
public struct ImportHistory: @unchecked Sendable {
    private static let key = "importedNoteFingerprints"
    private static let limit = 5_000
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var fingerprints: Set<String> {
        Set(defaults.stringArray(forKey: Self.key) ?? [])
    }

    public func record(_ notes: [ImportNote]) {
        var list = defaults.stringArray(forKey: Self.key) ?? []
        let known = Set(list)
        list.append(contentsOf: notes.map(\.fingerprint).filter { !known.contains($0) })
        defaults.set(Array(list.suffix(Self.limit)), forKey: Self.key)
    }

    public func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}

/// Notas que mandó el atajo de Apple Notes (`ImportNotesIntent`) y esperan la vista previa.
/// El intent corre en la app, a veces antes de que haya interfaz: deja las notas en disco y la app las toma.
public enum ImportInbox {
    public static let didReceive = Notification.Name("com.matiasrodriguezc.lumbre.importInbox")

    static func fileURL(in directory: URL) -> URL {
        directory.appending(path: "ImportInbox.json")
    }

    /// Suma notas al buzón (si ya había, se agregan al final).
    public static func post(_ notes: [ImportNote], directory: URL = LumbreShared.containerURL) throws {
        let current = peek(directory: directory)
        let data = try JSONEncoder().encode(current + notes)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL(in: directory), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        NotificationCenter.default.post(name: didReceive, object: nil)
    }

    public static func peek(directory: URL = LumbreShared.containerURL) -> [ImportNote] {
        guard let data = try? Data(contentsOf: fileURL(in: directory)) else { return [] }
        return (try? JSONDecoder().decode([ImportNote].self, from: data)) ?? []
    }

    /// Devuelve las notas y vacía el buzón.
    public static func take(directory: URL = LumbreShared.containerURL) -> [ImportNote] {
        let notes = peek(directory: directory)
        try? FileManager.default.removeItem(at: fileURL(in: directory))
        return notes
    }
}

import LumbreCore
import LumbreDesign
import SwiftUI
import UniformTypeIdentifiers

/// De dónde salen las notas: lo eligió en la hoja o llegó del atajo de Apple Notes. Es el `source` de los eventos.
enum ImportOrigin: String, Sendable {
    case markdownFiles = "markdown_files"
    case obsidianFolder = "obsidian_folder"
    case appleNotes = "apple_notes"
}

/// Pedido para abrir la hoja de importar: vacía (elegir el origen) o con las notas que mandó el atajo.
struct ImportRequest: Identifiable {
    let id = UUID()
    var notes: [ImportNote]?
    var origin: ImportOrigin?
}

/// Importar notas (paso 89, flag `import_notes`): elegir archivos `.md`, una carpeta de Obsidian o ver cómo armar
/// el atajo de Apple Notes; vista previa para elegir, descartar, cambiar categorías y editar la tesis; y el envío
/// por la cola offline, con su progreso.
struct ImportNotesView: View {
    let request: ImportRequest

    @Environment(AppModel.self) private var appModel
    @Environment(\.api) private var api
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var step: Step = .choose
    @State private var origin: ImportOrigin = .markdownFiles
    @State private var pickerMode: PickerMode?
    @State private var batch: ImportBatch?
    @State private var scan = ImportScan()
    @State private var credits: Credits?
    @State private var editingNote: ImportNote?
    @State private var editedThesis = ""
    @State private var renamingGroup: String?
    @State private var newCategory = ""
    @State private var errorMessage: String?
    @State private var progress = Progress()

    private enum Step: Equatable {
        case choose, reading, preview, sending
    }

    private enum PickerMode {
        case files, folder
    }

    /// Lo que queda de cada cupo que importa para la vista previa (nil: el plan no tiene ese cupo).
    private struct Credits {
        var capturesToday: Int?
        var distill: Int?
        var imports: Int?
    }

    /// Cómo va el envío: cuántas de esta tanda faltan, si se frenó por el tope del día y cuántas se descartaron.
    private struct Progress {
        var total = 0
        var remaining = 0
        var waitingForQuota = false
        var discarded = 0
    }

    var body: some View {
        NavigationStack {
            content
                .scrollContentBackground(.hidden)
                .background(Palette.surface)
                .navigationTitle("Importar notas")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .fileImporter(
            isPresented: Binding(get: { pickerMode != nil }, set: { if !$0 { pickerMode = nil } }),
            allowedContentTypes: pickerMode == .folder ? [.folder] : Self.markdownTypes,
            allowsMultipleSelection: pickerMode != .folder
        ) { result in
            let mode = pickerMode
            pickerMode = nil
            switch result {
            case .success(let urls):
                guard !urls.isEmpty else { return }
                Task { await read(urls, folder: mode == .folder) }
            case .failure(let error):
                errorMessage = ErrorContent(error).message
            }
        }
        .alert("Editar la tesis", isPresented: Binding(get: { editingNote != nil }, set: { if !$0 { editingNote = nil } })) {
            TextField("Tesis", text: $editedThesis, axis: .vertical)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") {
                if let editingNote { batch?.setThesis(editedThesis, for: editingNote.id) }
            }
        } message: {
            Text("Si Lumbre no conceptualiza la nota, entra con esta frase. Después la podés cambiar en la Red.")
        }
        .alert("Cambiar la categoría", isPresented: Binding(get: { renamingGroup != nil }, set: { if !$0 { renamingGroup = nil } })) {
            TextField("Categoría", text: $newCategory)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") {
                if let renamingGroup { batch?.setCategory(newCategory, forGroup: renamingGroup) }
            }
            .disabled(CategoryName.clean(newCategory).isEmpty)
        } message: {
            Text("Las notas de este grupo entran en esta categoría. Si no existe, se crea.")
        }
        .alert("No pudimos leer las notas", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            Analytics.screen("import_notes")
            if let notes = request.notes {
                origin = request.origin ?? .appleNotes
                var scan = ImportScan()
                scan.notes = notes
                await preview(scan)
            }
        }
        .interactiveDismissDisabled(step == .reading)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        switch step {
        case .choose, .reading:
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
        case .preview:
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let batch {
                    let all = batch.selected.count == batch.notes.count
                    Button(all ? "Ninguna" : "Todas") { self.batch?.setAll(!all) }
                }
            }
        case .sending:
            ToolbarItem(placement: .confirmationAction) {
                Button("Listo") { dismiss() }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .choose: chooseList
        case .reading: readingView
        case .preview: previewList
        case .sending: sendingView
        }
    }

    // MARK: Elegir el origen

    private var chooseList: some View {
        List {
            Section {
                sourceButton("Archivos Markdown", detail: "Uno o varios archivos .md desde Archivos.", systemImage: "doc.text") {
                    origin = .markdownFiles
                    pickerMode = .files
                }
                sourceButton("Una carpeta de Obsidian", detail: "La bóveda entera, con sus subcarpetas. Cada carpeta sugiere una categoría.", systemImage: "folder") {
                    origin = .obsidianFolder
                    pickerMode = .folder
                }
            } footer: {
                Text("Cada nota entra como una neurona. Las largas las conceptualiza Lumbre si le diste el permiso y te quedan conceptualizaciones; las demás entran con su primera línea, que podés editar antes.")
            }
            .listRowBackground(Palette.surfaceAlt)

            Section {
                VStack(alignment: .leading, spacing: Space.s2) {
                    Label("Apple Notes", systemImage: "note.text")
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                    Text("iOS no deja leer las notas desde otra app. Armá un atajo en Atajos:")
                        .font(.callout)
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: Space.s1) {
                        Text("1. Agregá la acción “Buscar notas” y elegí la carpeta o el filtro que quieras.")
                        Text("2. Agregá “Importar notas a Lumbre” y pasale las notas.")
                        Text("3. Corré el atajo: Lumbre se abre con la vista previa.")
                    }
                    .font(.callout)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, Space.s2)
                Button {
                    if let url = URL(string: "shortcuts://create-shortcut") { openURL(url) }
                } label: {
                    Label("Abrir Atajos", systemImage: "arrow.up.forward.app")
                }
                .foregroundStyle(Palette.infoText)
            }
            .listRowBackground(Palette.surfaceAlt)
        }
    }

    private func sourceButton(_ title: LocalizedStringKey, detail: LocalizedStringKey, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.s3) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(Palette.ink)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Palette.ink)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Space.s2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var readingView: some View {
        VStack(spacing: Space.s3) {
            ProgressView()
            Text("Leyendo tus notas…")
                .foregroundStyle(Palette.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Vista previa

    @ViewBuilder
    private var previewList: some View {
        if let batch {
            List {
                summarySection(batch)
                if batch.notes.contains(where: \.isLong) {
                    distillSection(batch)
                }
                ForEach(batch.groups) { group in
                    groupSection(group, batch: batch)
                }
            }
            .safeAreaInset(edge: .bottom) { importBar(batch) }
        }
    }

    private func summarySection(_ batch: ImportBatch) -> some View {
        Section {
            VStack(alignment: .leading, spacing: Space.s2) {
                Text(batch.notes.count == 1 ? "1 nota para importar" : "\(batch.notes.count) notas para importar")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Text("Tocá una nota para sacarla o volver a sumarla. Mantenela apretada para editar su tesis.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                if !batch.alreadyImported.isEmpty {
                    notice(batch.alreadyImported.count == 1
                           ? "1 ya la importaste antes: quedó sin elegir."
                           : "\(batch.alreadyImported.count) ya las importaste antes: quedaron sin elegir.", systemImage: "checkmark.circle")
                }
                let skipped = scan.skippedEmpty + scan.skippedUnreadable
                if skipped > 0 {
                    notice(skipped == 1 ? "1 archivo vacío o muy grande no se importa." : "\(skipped) archivos vacíos o muy grandes no se importan.", systemImage: "doc.badge.ellipsis")
                }
                if scan.truncated {
                    notice("La carpeta tiene más de \(NoteImport.maxFiles) notas: se leyeron las primeras.", systemImage: "exclamationmark.triangle")
                }
            }
            .padding(.vertical, Space.s1)
        }
        .listRowBackground(Palette.surfaceAlt)
    }

    @ViewBuilder
    private func distillSection(_ batch: ImportBatch) -> some View {
        Section {
            if !AIConsent.isGranted {
                VStack(alignment: .leading, spacing: Space.s2) {
                    Text("Sin tu permiso para usar IA, las notas largas entran con su primera línea.")
                        .font(.callout)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Revisar el permiso") { appModel.presentAIConsent() }
                        .foregroundStyle(Palette.infoText)
                }
            } else if (credits?.distill ?? 0) == 0 {
                Text("No te quedan conceptualizaciones este mes: las notas largas entran con su primera línea.")
                    .font(.callout)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Toggle(isOn: Binding(get: { batch.distillLongNotes }, set: { self.batch?.distillLongNotes = $0 })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Conceptualizar las notas largas")
                            .foregroundStyle(Palette.ink)
                        Text("Lumbre saca la idea de las notas de 30 palabras o más.")
                            .font(.footnote)
                            .foregroundStyle(Palette.inkMuted)
                    }
                }
                if batch.distillLongNotes && batch.longNotesWithoutDistill > 0 {
                    notice(batch.longNotesWithoutDistill == 1
                           ? "Te quedan \(credits?.distill ?? 0) conceptualizaciones este mes: 1 nota larga entra con su primera línea."
                           : "Te quedan \(credits?.distill ?? 0) conceptualizaciones este mes: \(batch.longNotesWithoutDistill) notas largas entran con su primera línea.",
                           systemImage: "info.circle")
                }
            }
        } header: {
            Text("Notas largas")
        }
        .listRowBackground(Palette.surfaceAlt)
    }

    private func groupSection(_ group: ImportBatch.Group, batch: ImportBatch) -> some View {
        Section {
            ForEach(group.notes) { note in
                noteRow(note, batch: batch)
            }
        } header: {
            HStack {
                Label(group.category, systemImage: group.id.isEmpty ? "tray" : "folder")
                    .lineLimit(1)
                Spacer()
                Menu {
                    Button {
                        newCategory = group.category
                        renamingGroup = group.id
                    } label: {
                        Label("Cambiar la categoría", systemImage: "tag")
                    }
                    Button {
                        self.batch?.setAll(true, inGroup: group.id)
                    } label: {
                        Label("Elegir todas", systemImage: "checkmark.circle")
                    }
                    Button {
                        self.batch?.setAll(false, inGroup: group.id)
                    } label: {
                        Label("No importar ninguna", systemImage: "circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(Text("Opciones de \(group.category)"))
            }
        }
        .listRowBackground(Palette.surfaceAlt)
    }

    private func noteRow(_ note: ImportNote, batch: ImportBatch) -> some View {
        let isSelected = batch.selected.contains(note.id)
        let distilled = batch.distilledIDs.contains(note.id)
        return Button {
            self.batch?.toggle(note.id)
        } label: {
            HStack(alignment: .top, spacing: Space.s3) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Palette.ink : Palette.inkMuted)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Space.s1) {
                    Text(batch.thesis(for: note))
                        .font(.body.weight(.medium))
                        .foregroundStyle(isSelected ? Palette.ink : Palette.inkMuted)
                        .lineLimit(3)
                    if let excerpt = note.excerpt {
                        Text(excerpt)
                            .font(.footnote)
                            .foregroundStyle(Palette.inkMuted)
                            .lineLimit(2)
                    }
                    if distilled || batch.alreadyImported.contains(note.id) {
                        HStack(spacing: Space.s2) {
                            if distilled {
                                Label("Lumbre la conceptualiza", systemImage: "sparkles")
                            }
                            if batch.alreadyImported.contains(note.id) {
                                Label("Ya importada", systemImage: "checkmark")
                            }
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Palette.inkMuted)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, Space.s1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text(isSelected ? "Tocá para no importarla" : "Tocá para importarla"))
        .accessibilityAction(named: Text("Editar la tesis")) { edit(note, batch: batch) }
        .contextMenu {
            Button {
                edit(note, batch: batch)
            } label: {
                Label("Editar la tesis", systemImage: "pencil")
            }
        }
    }

    private func edit(_ note: ImportNote, batch: ImportBatch) {
        editedThesis = batch.thesis(for: note)
        editingNote = note
    }

    private func importBar(_ batch: ImportBatch) -> some View {
        let count = batch.selected.count
        let limit = batchLimit
        return VStack(spacing: Space.s2) {
            if count > limit {
                VStack(spacing: Space.s1) {
                    Text(appModel.isPro
                         ? "Podés importar hasta \(limit) notas por vez."
                         : "Con el plan gratis te quedan \(limit) notas para importar. Sacá algunas o elegí las primeras.")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                    HStack(spacing: Space.s3) {
                        Button("Elegir las primeras \(limit)") {
                            self.batch?.selected = Set(batch.selectedNotes.prefix(limit).map(\.id))
                        }
                        .buttonStyle(.lumbre(.ghost))
                        if !appModel.isPro && FeatureFlag.paywall.isEnabled {
                            Button("Ver Pro") { appModel.presentPaywall(trigger: "import_notes") }
                                .buttonStyle(.lumbre(.ghost))
                        }
                    }
                }
            } else if let today = credits?.capturesToday, count > today {
                Text(today == 0
                     ? "Hoy ya usaste tus capturas: las notas entran mañana."
                     : "Hoy te quedan \(today) capturas: entran \(today) notas y las otras \(count - today) siguen mañana.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                Task { await submit() }
            } label: {
                Text(count == 1 ? "Importar 1 nota" : "Importar \(count) notas")
            }
            .buttonStyle(.lumbre(.primary, fullWidth: true))
            .disabled(count == 0 || count > limit)
        }
        .padding(.horizontal, Space.s4)
        .padding(.vertical, Space.s3)
        .background(.bar)
    }

    private var batchLimit: Int {
        NoteImport.batchLimit(plan: appModel.profile?.plan ?? .free, remaining: credits?.imports)
    }

    // MARK: Envío

    private var sendingView: some View {
        VStack(spacing: Space.s4) {
            Spacer()
            if progress.remaining == 0 {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(Palette.success)
                    .accessibilityHidden(true)
                Text("Tus notas ya están en la Red")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                if progress.discarded > 0 {
                    Text(progress.discarded == 1 ? "1 nota no se pudo importar." : "\(progress.discarded) notas no se pudieron importar.")
                        .font(.callout)
                        .foregroundStyle(Palette.inkMuted)
                }
                Button("Ver la Red") {
                    appModel.selectedTab = .vault
                    dismiss()
                }
                .buttonStyle(.lumbre(.primary))
            } else if progress.waitingForQuota {
                Image(systemName: "moon.zzz")
                    .font(.system(size: 44))
                    .foregroundStyle(Palette.inkMuted)
                    .accessibilityHidden(true)
                Text("Llegaste al tope de capturas de hoy")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                Text(progress.remaining == 1
                     ? "La nota que falta queda guardada en el teléfono y se suma a tu Red mañana."
                     : "Las \(progress.remaining) notas que faltan quedan guardadas en el teléfono y se suman a tu Red mañana.")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(.center)
            } else {
                ProgressView(value: Double(progress.total - progress.remaining), total: Double(max(progress.total, 1)))
                    .tint(Palette.ink)
                    .frame(maxWidth: 240)
                Text("Importando \(progress.total - progress.remaining) de \(progress.total)…")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
                Text("Podés cerrar esto: siguen entrando aunque no tengas conexión.")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(Space.s5)
        .frame(maxWidth: .infinity)
        .task { await followQueue() }
    }

    // MARK: Acciones

    private func read(_ urls: [URL], folder: Bool) async {
        step = .reading
        let scan = await Task.detached(priority: .userInitiated) {
            folder ? NoteImport.readFolder(urls[0]) : NoteImport.readFiles(urls)
        }.value
        guard !scan.notes.isEmpty else {
            step = .choose
            errorMessage = String(localized: "No encontramos notas con texto en lo que elegiste. Probá con archivos .md.")
            return
        }
        await preview(scan)
    }

    private func preview(_ scan: ImportScan) async {
        step = .reading
        self.scan = scan
        await loadCredits()
        var batch = ImportBatch(notes: scan.notes, fallbackCategory: String(localized: "Notas importadas"), history: ImportHistory().fingerprints)
        batch.distillAllowance = credits?.distill ?? 0
        batch.distillLongNotes = AIConsent.isGranted && batch.distillAllowance > 0
        // Si hay más de las que se pueden importar, arrancan elegidas las primeras.
        let limit = batchLimit
        if batch.selected.count > limit {
            batch.selected = Set(batch.selectedNotes.prefix(limit).map(\.id))
        }
        self.batch = batch
        step = .preview
        Analytics.track(.importPreviewed(source: origin.rawValue, notes: scan.notes.count, alreadyImported: batch.alreadyImported.count))
        #if DEBUG
        if Self.autoSubmit {
            try? await Task.sleep(for: .seconds(2))
            await submit()
        }
        #endif
    }

    private func loadCredits() async {
        guard let list = try? await api.credits() else {
            credits = Credits()
            return
        }
        credits = Credits(
            capturesToday: list.first { $0.kind == .capture }?.remaining,
            distill: list.first { $0.kind == .distill }?.remaining ?? 0,
            imports: list.first { $0.kind == .importNotes }?.remaining
        )
    }

    private func submit() async {
        guard let batch else { return }
        let requests = batch.requests()
        do {
            try await CaptureQueue.shared.enqueue(contentsOf: requests)
        } catch {
            errorMessage = String(localized: "No pudimos guardar las notas en el teléfono. Probá de nuevo.")
            return
        }
        ImportHistory().record(batch.selectedNotes)
        Analytics.track(.importSubmitted(
            source: origin.rawValue, selected: requests.count,
            discarded: batch.notes.count - requests.count, categories: batch.categories.count
        ))
        progress = Progress(total: requests.count, remaining: requests.count)
        step = .sending
        await CaptureQueue.shared.startMonitoring(api: api)
    }

    /// Sigue la cola hasta que entran todas las notas de esta tanda (o se frena por el tope del día).
    private func followQueue() async {
        let queue = CaptureQueue.shared
        progress.waitingForQuota = await queue.waitingForQuotaUntil != nil
        for await update in await queue.updates() {
            switch update {
            case .count:
                let pending = await queue.pending.filter { $0.importSource != nil }.count
                progress.remaining = min(progress.total, pending)
            case .waitingForQuota(let waiting):
                progress.waitingForQuota = waiting
            case .discarded:
                progress.discarded += 1
            case .flushed:
                break
            }
            if progress.remaining == 0 { break }
        }
        #if DEBUG
        if Self.autoSubmit && progress.remaining == 0 {
            try? await Task.sleep(for: .seconds(2))
            appModel.selectedTab = .vault
            dismiss()
        }
        #endif
    }

    #if DEBUG
    /// `-importAutoSubmit YES`: importa lo elegido sin tocar el botón y vuelve a la Red (para probar desde la terminal).
    private static var autoSubmit: Bool { UserDefaults.standard.bool(forKey: "importAutoSubmit") }
    #endif

    private func notice(_ text: LocalizedStringKey, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(Palette.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private static let markdownTypes: [UTType] = [
        UTType("net.daringfireball.markdown"), UTType(filenameExtension: "md"), UTType(filenameExtension: "markdown"), .plainText,
    ].compactMap { $0 }
}

#Preview("Vista previa") {
    ImportNotesView(request: ImportRequest(notes: [
        NoteImport.plainNote("Lista de ideas\nUna app que conecta recetas con la temporada.")!,
        NoteImport.plainNote("Ciclones\n" + String(repeating: "Un flujo en espiral separa partículas. ", count: 8))!,
        NoteImport.markdown("# Ritmo\nLa repetición crea expectativa.", fileName: "Ritmo.md", folder: "Música")!,
    ], origin: .appleNotes))
    .environment(AppModel.preview())
    .tint(Palette.ink)
}

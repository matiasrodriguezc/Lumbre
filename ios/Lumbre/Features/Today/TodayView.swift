import LumbreCore
import LumbreDesign
import SwiftUI

/// Hoy: el contador, la chispa del día con su reveal, las extras y las anteriores.
struct TodayView: View {
    @Environment(\.api) private var api
    @Environment(AppModel.self) private var appModel
    @Environment(\.dataVersion) private var dataVersion
    @State private var path: [SparkRoute] = []
    @State private var today: TodayState?
    @State private var recent: [Spark] = []
    @State private var loadError: Error?
    /// Chispa protagonista: la diaria, o la extra recién pedida.
    @State private var heroID: Spark.ID?
    @State private var isRequestingExtra = false
    @State private var extraError: String?
    @State private var trackedEmptyReason: String?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s6) {
                    if let loadError, today == nil {
                        LoadErrorView(error: loadError) { Task { await load() } }
                    } else if let today {
                        content(today)
                    } else {
                        placeholder
                    }
                }
                .padding(.horizontal, Space.s4)
                .padding(.bottom, Space.s8)
            }
            .background(Palette.bg)
            .navigationTitle("Hoy")
            .sparkDestinations()
            .task(id: dataVersion) { await load() }
            .refreshable { await load() }
            .onAppear { Analytics.screen("today") }
            .onChange(of: appModel.pendingRoute, initial: true) { consumeRoute() }
        }
    }

    // MARK: Contenido

    @ViewBuilder
    private func content(_ today: TodayState) -> some View {
        meter(today.quota)

        if let hero = hero(in: today) {
            if hero.status == .discarded {
                usedState(hero, quota: today.quota)
            } else {
                SparkHero(spark: hero) { updated in replace(updated) }
                    .id(hero.id)
            }
            if !hero.isPending {
                if today.needsMoreConcepts {
                    // Si el contador ya ofrece Capturar, el aviso no repite el botón.
                    needsMoreNotice(showsCapture: !earnsExtras(today.quota))
                }
                if FeatureFlag.extraSparks.isEnabled {
                    extraSection(today.quota)
                }
            }
        } else {
            emptyState(today)
        }

        let others = otherSparksToday(in: today)
        if !others.isEmpty {
            sparkList(title: "También hoy", sparks: others)
        }
        let previous = previousSparks(excluding: today)
        if !previous.isEmpty {
            sparkList(title: "Anteriores", sparks: previous)
        }
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: Space.s6) {
            SparkMeter(available: 1, total: 1, status: Text("Chispa disponible"), detail: Text("Se recarga mañana a las 8:00"))
            SparkCard(a: SparkSide(MockData.todaySpark.conceptA), b: SparkSide(MockData.todaySpark.conceptB), title: MockData.todaySpark.title, explanation: MockData.todaySpark.body) {
                EmptyView()
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }

    // MARK: Contador

    @ViewBuilder
    private func meter(_ quota: SparkQuota) -> some View {
        let showsEarn = earnsExtras(quota)
        VStack(alignment: .leading, spacing: Space.s2) {
            SparkMeter(
                available: quota.available,
                total: quota.total,
                status: quota.available > 1
                    ? Text("Te quedan \(quota.available) chispas hoy")
                    : quota.available == 1 ? Text("Chispa disponible") : Text("Usaste las chispas de hoy"),
                detail: quota.available == 0 && showsEarn
                    ? earnText(quota.conceptsUntilExtra)
                    : refillText(quota.refillsAt)
            )
            if showsEarn {
                HStack(spacing: Space.s3) {
                    Group {
                        if quota.available > 0 {
                            earnText(quota.conceptsUntilExtra)
                        } else {
                            refillText(quota.refillsAt)
                        }
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        appModel.presentCapture(entry: "earn_extra")
                    } label: {
                        Label("Capturar", systemImage: "plus")
                    }
                    .buttonStyle(.lumbre(.secondary))
                }
                .padding(.horizontal, Space.s1)
            }
        }
    }

    /// Free: guardar conceptos hoy da chispas extra.
    private func earnsExtras(_ quota: SparkQuota) -> Bool {
        !appModel.isPro && !appModel.isGuest && quota.conceptsUntilExtra > 0
    }

    private func earnText(_ count: Int) -> Text {
        Text("Guardá ^[\(count) concepto](inflect: true) para ganar 1 extra")
    }

    // MARK: Extras

    @ViewBuilder
    private func extraSection(_ quota: SparkQuota) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Otra chispa")
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            if quota.extraRemaining > 0 {
                Button(action: requestExtra) {
                    HStack(spacing: Space.s2) {
                        if isRequestingExtra {
                            ProgressView()
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isRequestingExtra ? "Encendiendo…" : "Pedir otra chispa")
                    }
                }
                .buttonStyle(.lumbre(.secondary, fullWidth: true))
                .disabled(isRequestingExtra)
                Group {
                    if quota.extraRemaining == 1 {
                        Text("Te queda 1 chispa extra hoy.")
                    } else {
                        Text("Te quedan \(quota.extraRemaining) chispas extra hoy.")
                    }
                }
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
            } else if appModel.isPro {
                Text("Ya usaste las chispas extra de hoy. Mañana tenés más.")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
            } else if !appModel.isGuest {
                Text("Cada 3 conceptos que guardás hoy ganás una chispa extra, hasta 2 por día.")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                if FeatureFlag.paywall.isEnabled {
                    Button {
                        appModel.presentPaywall(trigger: "extra_sparks")
                    } label: {
                        Text("Con Pro, hasta 10 por día")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.proText)
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                }
            } else {
                Text("Creá tu cuenta para ganar chispas extra guardando conceptos.")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
            }
            if let extraError {
                ActionNotice(text: "\(extraError)", symbol: "exclamationmark.triangle.fill", color: Palette.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func requestExtra() {
        guard !isRequestingExtra else { return }
        isRequestingExtra = true
        extraError = nil
        Analytics.track(.sparkExtraRequested(mode: .extra, source: appModel.isPro ? "pro" : "earned"))
        Task {
            defer { isRequestingExtra = false }
            do {
                let spark = try await api.requestSpark(pick: nil)
                if let today {
                    self.today = TodayState(spark: today.spark, quota: today.quota, extras: [spark] + today.extras, runwayDays: today.runwayDays, conceptCount: today.conceptCount)
                }
                heroID = spark.id
                appModel.dataChanged()
            } catch LumbreAPIError.proRequired {
                appModel.presentPaywall(trigger: "extra_sparks")
            } catch {
                extraError = error.localizedDescription
            }
        }
    }

    // MARK: Avisos y vacíos

    private func needsMoreNotice(showsCapture: Bool) -> some View {
        HStack(alignment: .top, spacing: Space.s3) {
            Image(systemName: "tray.and.arrow.down")
                .foregroundStyle(Palette.infoText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.s2) {
                Text("Te quedan pocas combinaciones nuevas")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text("Guardá algunos conceptos más para que las chispas sigan sorprendiendo.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                if showsCapture {
                    Button("Capturar conceptos") { appModel.presentCapture(entry: "earn_extra") }
                        .buttonStyle(.lumbre(.secondary))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Space.s4)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
    }

    private func usedState(_ spark: Spark, quota: SparkQuota) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Ya usaste la chispa de hoy")
                .font(.headline)
                .foregroundStyle(Palette.ink)
            Text("Marcaste que esta no te sirve. Con eso elegimos mejor la de mañana.")
                .font(.callout)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink(value: SparkRoute.detail(spark.id)) {
                SparkRow(spark: spark)
            }
            .buttonStyle(.plain)
        }
        .onAppear { trackEmpty("used_today") }
    }

    @ViewBuilder
    private func emptyState(_ today: TodayState) -> some View {
        let fewConcepts = today.conceptCount < 4
        ContentUnavailableView {
            EmptyStateLabel(fewConcepts ? "Todavía no hay material para combinar" : "Hoy no encontramos un buen par", systemImage: "sparkles",
                            illustration: fewConcepts ? .emptyVault : .beforeSpark)
        } description: {
            if fewConcepts {
                Text("Guardá algunos conceptos de temas distintos: una frase, un link o una nota de voz. Con eso Lumbre enciende tu primera chispa.")
            } else {
                Text("Guardá conceptos de otros temas. Los choques entre mundos distintos dan las mejores chispas.")
            }
        } actions: {
            Button("Capturar conceptos") { appModel.presentCapture(entry: "earn_extra") }
                .buttonStyle(.lumbre(.secondary))
        }
        .onAppear { trackEmpty(fewConcepts ? "few_concepts" : "no_candidates") }
    }

    private func trackEmpty(_ reason: String) {
        guard trackedEmptyReason != reason else { return }
        trackedEmptyReason = reason
        Analytics.track(.sparkEmptyStateShown(reason: reason))
    }

    // MARK: Listas

    private func sparkList(title: LocalizedStringKey, sparks: [Spark]) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(sparks) { spark in
                NavigationLink(value: SparkRoute.detail(spark.id)) {
                    SparkRow(spark: spark)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func hero(in today: TodayState) -> Spark? {
        if let heroID, let extra = today.extras.first(where: { $0.id == heroID }) {
            return extra
        }
        return today.spark
    }

    private func otherSparksToday(in today: TodayState) -> [Spark] {
        let heroID = hero(in: today)?.id
        let all = (today.spark.map { [$0] } ?? []) + today.extras
        return all.filter { $0.id != heroID }
    }

    private func previousSparks(excluding today: TodayState) -> [Spark] {
        let todayIDs = Set((today.spark.map { [$0.id] } ?? []) + today.extras.map(\.id))
        return recent.filter { !todayIDs.contains($0.id) }
    }

    // MARK: Datos

    private func load() async {
        do {
            async let state = api.today()
            async let recentSparks = api.recentSparks()
            let (loaded, previous) = try await (state, recentSparks)
            today = loaded
            recent = previous
            loadError = nil
        } catch {
            loadError = error
        }
        consumeRoute()
    }

    /// Actualiza una chispa en el estado local (después del reveal, guardar o "No me sirve").
    private func replace(_ spark: Spark) {
        guard let today else { return }
        let daily = today.spark?.id == spark.id ? spark : today.spark
        let extras = today.extras.map { $0.id == spark.id ? spark : $0 }
        self.today = TodayState(spark: daily, quota: today.quota, extras: extras, runwayDays: today.runwayDays, conceptCount: today.conceptCount)
    }

    /// Links profundos, pushes y el widget: `.today` vuelve a la raíz; `.spark(id)` abre esa chispa.
    /// Si es la chispa protagonista de hoy, se queda en Hoy para hacer el reveal.
    private func consumeRoute() {
        switch appModel.pendingRoute {
        case .today:
            appModel.pendingRoute = nil
            path = []
        case .spark(let id):
            guard let today else { return }
            appModel.pendingRoute = nil
            let todayIDs = (today.spark.map { [$0.id] } ?? []) + today.extras.map(\.id)
            if todayIDs.contains(id), (today.spark?.id == id ? today.spark : today.extras.first { $0.id == id })?.isPending == true {
                heroID = today.spark?.id == id ? nil : id
                path = []
            } else {
                path = [.detail(id)]
            }
        default:
            break
        }
    }
}

/// Fila de una chispa en las listas (Hoy, proyectos).
struct SparkRow: View {
    let spark: Spark
    /// Dentro de un proyecto no repite dónde está guardada: muestra la fecha.
    var showsProject = true

    var body: some View {
        HStack(spacing: Space.s3) {
            Image(systemName: spark.statusSymbol)
                .foregroundStyle(Palette.inkMuted)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(spark.isPending ? String(localized: "Chispa por encender") : spark.title)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                Group {
                    if showsProject || spark.status != .saved {
                        spark.statusLine
                    } else {
                        Text(spark.scheduledFor ?? spark.createdAt, format: .relative(presentation: .named))
                    }
                }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.inkMuted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkMuted)
                .accessibilityHidden(true)
        }
        .padding(Space.s4)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TodayView()
        .environment(AppModel())
        .preferredColorScheme(.dark)
}

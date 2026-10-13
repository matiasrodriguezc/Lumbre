import LumbreCore
import LumbreDesign
import StoreKit
import SwiftUI

/// Paywall de Lumbre Pro (plan.md §8). Aparece solo al tocar algo Pro, nunca al abrir la app.
/// Precio, período, cómo cancelar, Restaurar compras, términos y privacidad siempre visibles (plan.md §10).
struct PaywallView: View {
    /// `trigger` de `paywall_shown`: `planner`, `distill`, `extra_sparks`, `problem_mode`, `graph`, `settings`.
    let trigger: String
    var variant = "default"

    @Environment(\.api) private var api
    @Environment(\.purchases) private var purchases
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var offers: [PlanOffer] = []
    @State private var loadError: Error?
    @State private var isLoading = true
    @State private var selected: PlanPeriod = .annual
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var alert: PaywallAlert?
    @State private var shownAt = Date.now
    @State private var didPurchase = false
    @State private var isManagingSubscription = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s6) {
                    header
                    benefits
                    if appModel.isPro {
                        alreadyPro
                    } else {
                        plans
                        finePrint
                    }
                    footerLinks
                }
                .padding(.horizontal, Space.s4)
                .padding(.bottom, Space.s6)
            }
            .safeAreaInset(edge: .bottom) {
                if !appModel.isPro, loadError == nil {
                    purchaseBar
                }
            }
            .neuralBackground()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .interactiveDismissDisabled(isPurchasing)
        .task { await loadOffers() }
        .onAppear {
            shownAt = .now
            Analytics.screen("paywall")
            Analytics.track(.paywallShown(trigger: trigger, variant: variant))
        }
        .onDisappear {
            guard !didPurchase else { return }
            Analytics.track(.paywallDismissed(trigger: trigger, variant: variant, secondsVisible: Int(Date.now.timeIntervalSince(shownAt))))
        }
        .alert(item: $alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("Entendido")))
        }
        .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
    }

    // MARK: Contenido

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("Lumbre Pro")
                .lumbreDisplay(.title1)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Más chispas por día y un plan para cada idea.")
                .font(.body)
                .foregroundStyle(Palette.inkMuted)
        }
        .padding(.top, Space.s2)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            benefit("Hasta 10 chispas por día, y elegís qué neuronas se conectan")
            benefit("Destilación automática de links, fotos y PDFs")
            benefit("Planificador para bajar cada idea a tareas")
            benefit("Circuitos ilimitados")
        }
    }

    private func benefit(_ text: LocalizedStringKey) -> some View {
        Label {
            Text(text)
                .font(.body)
                .foregroundStyle(Palette.ink)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Palette.proText)
        }
    }

    @ViewBuilder
    private var plans: some View {
        if isLoading {
            VStack(spacing: Space.s3) {
                PlanTilePlaceholder()
                PlanTilePlaceholder()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Cargando los precios"))
        } else if let loadError {
            VStack(alignment: .leading, spacing: Space.s3) {
                Label {
                    Text(loadError.localizedDescription)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Palette.warning)
                }
                .font(.callout)
                .foregroundStyle(Palette.ink)
                Button("Reintentar") { Task { await loadOffers() } }
                    .buttonStyle(.lumbre(.secondary))
            }
            .padding(Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        } else {
            VStack(spacing: Space.s3) {
                ForEach(offers) { offer in
                    tile(for: offer)
                }
            }
        }
    }

    private func tile(for offer: PlanOffer) -> some View {
        let isSelected = selected == offer.period
        switch offer.period {
        case .annual:
            let detail: Text = if let days = offer.trialDays {
                Text("\(offer.monthlyEquivalent) por mes · \(days) días gratis")
            } else {
                Text("\(offer.monthlyEquivalent) por mes")
            }
            return PlanTile(name: "Anual", price: offer.displayPrice, period: "por año", detail: detail,
                            badge: savingsPercent.map { Text("Ahorrás \($0)%") }, isSelected: isSelected) {
                selected = .annual
            }
        case .monthly:
            return PlanTile(name: "Mensual", price: offer.displayPrice, period: "por mes", detail: Text("Cancelás cuando quieras"),
                            isSelected: isSelected) {
                selected = .monthly
            }
        }
    }

    private var finePrint: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            if let offer = selectedOffer, let days = offer.trialDays {
                Text("Tenés \(days) días gratis. Si cancelás antes de que terminen, no se te cobra nada.")
            }
            Text("La suscripción se cobra en tu cuenta de Apple y se renueva sola al mismo precio, salvo que la canceles al menos 24 horas antes del fin del período.")
            Text("Cancelala cuando quieras desde Ajustes > tu nombre > Suscripciones.")
        }
        .font(.footnote)
        .foregroundStyle(Palette.inkMuted)
    }

    private var alreadyPro: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Label {
                Text("Ya tenés Lumbre Pro")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
            } icon: {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Palette.proText)
            }
            Text("Gracias por bancar Lumbre. Tu suscripción se administra desde tu cuenta de Apple.")
                .font(.callout)
                .foregroundStyle(Palette.inkMuted)
            Button("Administrar suscripción") { isManagingSubscription = true }
                .buttonStyle(.lumbre(.secondary))
        }
        .padding(Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private var footerLinks: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.s4) { footerButtons }
            VStack(alignment: .leading, spacing: Space.s2) { footerButtons }
        }
        .font(.footnote.weight(.medium))
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var footerButtons: some View {
        Button {
            Task { await restore() }
        } label: {
            if isRestoring {
                ProgressView().controlSize(.small)
            } else {
                Text("Restaurar compras")
            }
        }
        .disabled(isRestoring || isPurchasing)
        Button("Términos") { openURL(LegalLinks.terms) }
        Button("Privacidad") { openURL(LegalLinks.privacy) }
    }

    private var purchaseBar: some View {
        VStack(spacing: Space.s2) {
            Button {
                Task { await buy() }
            } label: {
                if isPurchasing {
                    ProgressView()
                        .tint(Palette.onPro)
                        .accessibilityLabel(Text("Comprando"))
                } else {
                    ctaTitle
                }
            }
            .buttonStyle(.lumbre(.pro, fullWidth: true))
            .disabled(selectedOffer == nil || isPurchasing || isRestoring)

            if let offer = selectedOffer {
                ctaCaption(offer)
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Space.s4)
        .padding(.top, Space.s3)
        .padding(.bottom, Space.s2)
        .background(Palette.bg)
    }

    private var ctaTitle: Text {
        guard let offer = selectedOffer else { return Text("Probar 7 días gratis") }
        if let days = offer.trialDays { return Text("Probar \(days) días gratis") }
        return offer.period == .annual
            ? Text("Suscribirme por \(offer.displayPrice) al año")
            : Text("Suscribirme por \(offer.displayPrice) al mes")
    }

    private func ctaCaption(_ offer: PlanOffer) -> Text {
        switch (offer.period, offer.trialDays) {
        case (.annual, .some): Text("Después, \(offer.displayPrice) por año. Cancelás cuando quieras.")
        case (.annual, .none): Text("\(offer.displayPrice) por año. Cancelás cuando quieras.")
        case (.monthly, _): Text("\(offer.displayPrice) por mes. Cancelás cuando quieras.")
        }
    }

    // MARK: Datos

    private var selectedOffer: PlanOffer? {
        offers.first { $0.period == selected }
    }

    /// Cuánto se ahorra con el anual respecto de 12 meses del mensual.
    private var savingsPercent: Int? {
        guard let annual = offers.first(where: { $0.period == .annual }),
              let monthly = offers.first(where: { $0.period == .monthly }),
              monthly.price > 0 else { return nil }
        let ratio = (annual.price / (monthly.price * 12) as NSDecimalNumber).doubleValue
        let percent = Int(((1 - ratio) * 100).rounded(.down))
        return percent >= 5 ? percent : nil
    }

    private func loadOffers() async {
        isLoading = true
        loadError = nil
        do {
            offers = try await purchases.offers()
            if !offers.contains(where: { $0.period == selected }), let first = offers.first {
                selected = first.period
            }
        } catch {
            loadError = error
            Analytics.track(.errorShown(screen: "paywall", code: "store_products"))
        }
        isLoading = false
    }

    private func buy() async {
        guard let offer = selectedOffer else { return }
        Analytics.track(.purchaseStarted(product: offer.period.rawValue, trigger: trigger, variant: variant))
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await purchases.purchase(offer) {
            case .purchased:
                await activatePro()
                didPurchase = true
                dismiss()
            case .pending:
                alert = .pending
            case .cancelled:
                break
            }
        } catch {
            Analytics.track(.errorShown(screen: "paywall", code: "store_purchase"))
            alert = .storeError(error.localizedDescription)
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            let found = try await purchases.restore()
            Analytics.track(.purchaseRestored(found: found))
            if found {
                await activatePro()
                didPurchase = true
                dismiss()
            } else {
                alert = .nothingToRestore
            }
        } catch {
            Analytics.track(.purchaseRestored(found: false))
            alert = .storeError(error.localizedDescription)
        }
    }

    /// Mientras no exista RevenueCat, en Debug se marca Pro a mano para poder probar el resto de la app.
    /// En producción el plan NO lo cambia la app: lo actualiza el webhook de RevenueCat en `profiles.plan`
    /// (paso 36) y acá solo se vuelve a cargar el perfil.
    private func activatePro() async {
        #if DEBUG
        try? await api.setPlanForDevelopment(.pro)
        #endif
        await appModel.loadProfile(api: api)
        appModel.dataChanged()
    }
}

private enum PaywallAlert: Identifiable {
    case pending
    case nothingToRestore
    case storeError(String)

    var id: String {
        switch self {
        case .pending: "pending"
        case .nothingToRestore: "nothing"
        case .storeError(let message): "error-\(message)"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .pending: "Compra pendiente"
        case .nothingToRestore: "No hay compras para restaurar"
        case .storeError: "No se pudo completar"
        }
    }

    var message: String {
        switch self {
        case .pending: String(localized: "La compra espera una aprobación. Cuando se apruebe, Pro se activa solo.")
        case .nothingToRestore: String(localized: "No encontramos una suscripción a Lumbre Pro en esta cuenta de Apple.")
        case .storeError(let message): message
        }
    }
}

#Preview("Free") {
    Color.clear.sheet(isPresented: .constant(true)) {
        PaywallView(trigger: "settings")
    }
    .environment(AppModel())
    .preferredColorScheme(.light)
    .tint(Palette.ink)
}

#Preview("Error de tienda") {
    PaywallView(trigger: "planner")
        .environment(\.purchases, PreviewPurchaseService(failsLoading: true))
        .environment(AppModel())
        .preferredColorScheme(.light)
}

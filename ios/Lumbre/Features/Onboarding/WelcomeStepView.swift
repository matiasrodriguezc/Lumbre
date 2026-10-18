import LumbreCore
import LumbreDesign
import SwiftUI

/// Paso 1: la propuesta en una línea, "Empezar" y "Ya tengo cuenta". Antes de seguir pide el consentimiento para IA.
struct WelcomeStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(AppModel.self) private var appModel
    @Environment(\.api) private var api
    @AppStorage("aiConsent") private var aiConsent: Bool?
    @State private var isShowingAccount = false
    @State private var isAskingConsent = false
    /// Entró a una cuenta ya configurada y falta el consentimiento para IA en este teléfono.
    @State private var signedInProfile: Profile?

    var body: some View {
        GeometryReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s8) {
                Wordmark(style: .title2)
                    .padding(.top, Space.s4)

                // La demo y la propuesta van centradas en lo que queda (en pantallas altas sobraba abajo).
                Spacer(minLength: 0)

                CollisionIllustration()

                VStack(alignment: .leading, spacing: Space.s3) {
                    Text("Donde se encienden las ideas")
                        .lumbreDisplay(.title1)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Guardá lo que te inspira. Cada mañana, dos de tus neuronas se conectan y salta una chispa.")
                        .font(.title3)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .leading)
            .padding(.horizontal, Space.s4)
            .padding(.bottom, Space.s6)
        }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Space.s2) {
                Button("Empezar") {
                    Analytics.track(.guestEntered)
                    continueAfterConsent()
                }
                .buttonStyle(.lumbre(.primary, fullWidth: true))

                Button("Ya tengo cuenta") { isShowingAccount = true }
                    .buttonStyle(.lumbre(.secondary, fullWidth: true))
            }
            .padding(.horizontal, Space.s4)
            .padding(.top, Space.s3)
            .padding(.bottom, Space.s2)
            .background(Palette.bg)
        }
        .neuralBackground()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            Analytics.screen(OnboardingStep.welcome.screenName)
            model.trackStartIfNeeded()
        }
        .sheet(isPresented: $isShowingAccount) {
            if FeatureFlag.emailAccount.isEnabled {
                AccountSheet(purpose: .signIn, continueAsGuestTitle: "Seguir como invitado", onContinueAsGuest: continueAsGuest) { profile, purpose in
                    afterSheetCloses { signedIn(profile, purpose: purpose) }
                }
            } else {
                AccountComingSoonSheet(onContinue: continueAsGuest)
            }
        }
        .sheet(isPresented: $isAskingConsent) {
            AIConsentSheet { granted in
                AIConsent.record(granted, api: api)
                isAskingConsent = false
                if let profile = signedInProfile {
                    signedInProfile = nil
                    appModel.accountChanged(to: profile, purpose: .signIn)
                } else {
                    model.complete(.welcome)
                }
            }
        }
    }

    private func continueAsGuest() {
        Analytics.track(.guestEntered)
        afterSheetCloses { continueAfterConsent() }
    }

    /// Deja que se cierre la sheet antes de abrir otra.
    private func afterSheetCloses(_ action: @escaping @MainActor () -> Void) {
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            action()
        }
    }

    /// Entró a su cuenta: si ya estaba configurada va directo a Hoy (antes, el consentimiento si en este teléfono
    /// todavía no lo dio); si es nueva, sigue el onboarding.
    private func signedIn(_ profile: Profile, purpose: EmailCodePurpose) {
        if profile.isOnboarded {
            if aiConsent == nil {
                signedInProfile = profile
                isAskingConsent = true
            } else {
                appModel.accountChanged(to: profile, purpose: purpose)
            }
        } else {
            appModel.setProfile(profile)
            continueAfterConsent()
        }
    }

    private func continueAfterConsent() {
        if aiConsent == nil {
            isAskingConsent = true
        } else {
            model.complete(.welcome)
        }
    }
}

/// Lo que hace Lumbre, contado en bucle con la misma sinapsis de la chispa: dos neuronas de mundos distintos se
/// tantean, se conectan, salta la chispa y aparece la idea. Con Reducir movimiento, quieta y ya conectada.
/// Sin la identidad neuronal, las dos tarjetas con una "×".
private struct CollisionIllustration: View {
    @Environment(\.neuralIdentity) private var neuralIdentity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var start = Date.now

    /// Un ciclo: se tantean (0 – 1,6 s), avanzan y se tocan (1,6 – 2,2), salta la chispa y se agarran (2,2 – 2,6),
    /// aparece la idea (2,4 – 2,9), queda a la vista y se funde (5,8 – 6,3) para volver a empezar.
    private static let cycle = 6.6

    var body: some View {
        Group {
            if neuralIdentity {
                TimelineView(.animation(paused: reduceMotion)) { context in
                    let elapsed = context.date.timeIntervalSince(start)
                    demo(t: reduceMotion ? 4 : elapsed.truncatingRemainder(dividingBy: Self.cycle))
                }
            } else {
                cardsFallback
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Ejemplo: onda verde de semáforos por code review"))
    }

    private func demo(t: Double) -> some View {
        let approach = ease(progress(t, 1.6, 2.2))
        let grip = ease(progress(t, 2.15, 2.6))
        let starOpacity = progress(t, 2.15, 2.25)
        // Rebote corto de la estrella: pasa un 15 % y vuelve.
        let pop = progress(t, 2.15, 2.5)
        let star = pop < 1 ? 0.2 + 0.95 * sin(pop * .pi * 0.62) / sin(.pi * 0.62) : 1
        let idea = ease(progress(t, 2.4, 2.9))
        let fadeOut = 1 - progress(t, 5.8, 6.3)
        return VStack(alignment: .leading, spacing: Space.s4) {
            SparkPairHeader(
                a: SparkSide(category: String(localized: "Urbanismo"), categorySymbol: "building.2",
                             title: String(localized: "Onda verde de semáforos")),
                b: SparkSide(category: String(localized: "Software"), categorySymbol: "chevron.left.forwardslash.chevron.right",
                             title: String(localized: "Code review"))
            )
            GrowthConeSynapse(approach: 0.12 + 0.88 * approach, grip: grip, star: star, starOpacity: starOpacity, live: !reduceMotion)
                .frame(maxWidth: 340)
                .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: Space.s2) {
                Text("Semáforos × code review")
                    .lumbreDisplay(.title2)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Si un PR se aprueba rápido, los siguientes del mismo autor entran en una “onda verde”.")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(idea)
            .offset(y: reduceMotion ? 0 : 8 * (1 - idea))
        }
        .padding(Space.s5)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
        .opacity(reduceMotion ? 1 : 0.15 + 0.85 * fadeOut)
    }

    private func progress(_ t: Double, _ a: Double, _ b: Double) -> Double { min(max((t - a) / (b - a), 0), 1) }
    private func ease(_ u: Double) -> Double { u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2 }

    private var cardsFallback: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.s2) { cards }
            VStack(alignment: .leading, spacing: Space.s2) { cards }
        }
    }

    @ViewBuilder
    private var cards: some View {
        miniCard(category: "Urbanismo", symbol: "building.2", title: "Onda verde de semáforos")
        Text(verbatim: "×")
            .font(.title2.weight(.semibold))
            .foregroundStyle(Palette.inkMuted)
        miniCard(category: "Software", symbol: "chevron.left.forwardslash.chevron.right", title: "Code review")
    }

    private func miniCard(category: LocalizedStringKey, symbol: String, title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Label(category, systemImage: symbol)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.inkMuted)
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.s4)
        .frame(minWidth: 140, maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 220, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
    }
}

/// Consentimiento explícito antes de mandar datos a una IA de terceros (plan.md §10, App Store 5.1.2).
struct AIConsentSheet: View {
    let onResponse: (Bool) -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s4) {
                    Image(systemName: "lock.shield")
                        .font(.largeTitle)
                        .foregroundStyle(Palette.infoText)
                        .accessibilityHidden(true)
                    Text("Tus ideas y la IA")
                        .lumbreDisplay(.title1)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text("Para conceptualizar lo que guardás y encender las chispas, Lumbre manda el texto de tus ideas a Claude, una IA de Anthropic.")
                        .font(.body)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: Space.s3) {
                        point("Solo se manda lo necesario para cada chispa: tus ideas y tu perfil creativo.", symbol: "text.quote")
                        point("Podés cambiar esto cuando quieras en Perfil > Privacidad.", symbol: "slider.horizontal.3")
                        point("Si no aceptás, podés guardar ideas igual, pero las chispas y la conceptualización necesitan este permiso.", symbol: "info.circle")
                    }
                    Button("Leer la política de privacidad") { openURL(LegalLinks.privacy) }
                        .font(.callout.weight(.medium))
                        .foregroundStyle(Palette.infoText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.s4)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: Space.s2) {
                    Button("Acepto") { onResponse(true) }
                        .buttonStyle(.lumbre(.primary, fullWidth: true))
                    Button("No acepto") { onResponse(false) }
                        .buttonStyle(.lumbre(.secondary, fullWidth: true))
                }
                .padding(.horizontal, Space.s4)
                .padding(.top, Space.s3)
                .padding(.bottom, Space.s2)
                .background(Palette.surface)
            }
            .background(Palette.surface)
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Radius.lg)
        .interactiveDismissDisabled()
    }

    private func point(_ text: LocalizedStringKey, symbol: String) -> some View {
        Label {
            Text(text)
                .font(.callout)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(Palette.inkMuted)
        }
    }
}

#Preview("Bienvenida") {
    NavigationStack {
        WelcomeStepView()
    }
    .environment(OnboardingModel(profile: nil))
    .environment(AppModel())
    .preferredColorScheme(.light)
}

#Preview("Consentimiento") {
    AIConsentSheet { _ in }
        .preferredColorScheme(.light)
}

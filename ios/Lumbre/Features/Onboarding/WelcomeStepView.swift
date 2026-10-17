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
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s8) {
                Wordmark(style: .title2)
                    .padding(.top, Space.s4)

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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.s4)
            .padding(.bottom, Space.s6)
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

/// Dos conceptos que chocan: lo que hace Lumbre, sin la estrella (que es solo de la chispa del día).
private struct CollisionIllustration: View {
    @Environment(\.neuralIdentity) private var neuralIdentity
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.s2) { cards(vertical: false) }
            VStack(alignment: .leading, spacing: Space.s2) { cards(vertical: true) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Ejemplo: onda verde de semáforos por code review"))
    }

    @ViewBuilder
    private func cards(vertical: Bool) -> some View {
        miniCard(category: "Urbanismo", symbol: "building.2", title: "Onda verde de semáforos")
        Group {
            if neuralIdentity {
                // Sin estrella: el único magenta de esta pantalla es "Empezar". Apiladas, la sinapsis va vertical.
                Synapse(.reaching)
                    .frame(width: 56)
                    .rotationEffect(.degrees(vertical ? 90 : 0))
                    .frame(height: vertical ? 56 : nil)
            } else {
                Text(verbatim: "×")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Palette.inkMuted)
            }
        }
        .frame(maxWidth: vertical ? 220 : .infinity)
        .layoutPriority(-1)
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
        // Con tamaños de accesibilidad, a todo el ancho: en 220 pt, "Urbanismo" y "semáforos" se cortaban por sílabas.
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

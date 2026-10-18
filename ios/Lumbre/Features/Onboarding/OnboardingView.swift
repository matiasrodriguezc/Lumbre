import LumbreCore
import LumbreDesign
import SwiftUI

/// Onboarding: bienvenida, perfil creativo, ideas semilla, hora de la chispa y permiso de push.
/// Termina guardando el perfil y cae en Hoy, donde espera la primera chispa.
struct OnboardingView: View {
    @Environment(AppModel.self) private var appModel
    @State private var model: OnboardingModel

    init(profile: Profile?) {
        _model = State(initialValue: OnboardingModel(profile: profile))
    }

    var body: some View {
        NavigationStack(path: $model.path) {
            WelcomeStepView()
                .navigationDestination(for: OnboardingStep.self) { step in
                    switch step {
                    case .welcome: WelcomeStepView()
                    case .profile: ProfileStepView()
                    case .seeds: SeedsStepView()
                    case .sparkHour: SparkHourStepView()
                    case .push: PushStepView()
                    }
                }
        }
        .environment(model)
        #if DEBUG
        .task {
            // `-mockGuest -open seeds`: arranca en ese paso, con los anteriores en la pila.
            if let raw = UserDefaults.standard.string(forKey: "open"), let step = OnboardingStep(rawValue: raw) {
                model.path = OnboardingStep.allCases.filter { $0 != .welcome && $0.index <= step.index }
            }
        }
        #endif
    }
}

/// Estructura común de los pasos 2 a 5: progreso, título, bajada, contenido y botones abajo.
struct OnboardingScaffold<Content: View, Footer: View>: View {
    let step: OnboardingStep
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s5) {
                OnboardingProgress(step: step)
                VStack(alignment: .leading, spacing: Space.s2) {
                    Text(title)
                        .lumbreDisplay(.title1)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content()
            }
            .padding(.horizontal, Space.s4)
            .padding(.bottom, Space.s6)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Space.s2) {
                footer()
            }
            .padding(.horizontal, Space.s4)
            .padding(.top, Space.s3)
            .padding(.bottom, Space.s2)
            .background(Palette.bg)
        }
        .neuralBackground()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Analytics.screen(step.screenName) }
    }
}

/// Barra de progreso de los pasos 2 a 5.
struct OnboardingProgress: View {
    let step: OnboardingStep
    private let steps: [OnboardingStep] = [.profile, .seeds, .push, .sparkHour]

    var body: some View {
        HStack(spacing: Space.s1) {
            ForEach(steps, id: \.self) { item in
                Capsule()
                    .fill(item.index <= step.index ? Palette.ink : Palette.border)
                    .frame(height: 4)
            }
        }
        .padding(.top, Space.s2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Paso \(step.index - 1) de \(steps.count)"))
    }
}

#Preview("Onboarding") {
    OnboardingView(profile: nil)
        .environment(AppModel())
        .preferredColorScheme(.light)
        .tint(Palette.ink)
}

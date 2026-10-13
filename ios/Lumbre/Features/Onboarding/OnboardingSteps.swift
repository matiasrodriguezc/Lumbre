import LumbreCore
import LumbreDesign
import SwiftUI

// MARK: - Perfil creativo

/// Paso 2: hasta dos perfiles creativos. Definen la lente de las chispas.
struct ProfileStepView: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        @Bindable var model = model
        OnboardingScaffold(step: .profile, title: "¿Qué querés crear?", subtitle: "Elegí hasta dos. Lo podés cambiar cuando quieras.") {
            CreativeProfilePicker(selection: $model.profiles)
        } footer: {
            Button("Continuar") { model.complete(.profile) }
                .buttonStyle(.lumbre(.primary, fullWidth: true))
                .disabled(model.profiles.isEmpty)
        }
    }
}

// MARK: - Ideas semilla

/// Paso 3: tres ideas con su categoría. Se puede seguir con una.
struct SeedsStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(\.api) private var api
    @State private var saveError: String?

    var body: some View {
        OnboardingScaffold(step: .seeds, title: "Tus primeras ideas", subtitle: "Algo que leíste, viste o pensaste. Con estas ideas sale tu primera chispa.") {
            VStack(alignment: .leading, spacing: Space.s4) {
                Label("Mejor si son de temas distintos: así chocan. Podés dictarlas con el micrófono del teclado.", systemImage: "lightbulb")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
                ForEach(model.seeds.indices, id: \.self) { index in
                    SeedCard(index: index)
                }
            }
        } footer: {
            Button {
                Task { await saveAndContinue() }
            } label: {
                if model.isSavingSeeds {
                    ProgressView()
                        .tint(Palette.onAccent)
                        .accessibilityLabel(Text("Guardando"))
                } else {
                    Text(buttonTitle)
                }
            }
            .buttonStyle(.lumbre(.primary, fullWidth: true))
            .disabled(model.filledSeedCount == 0 || model.isSavingSeeds)

            if model.filledSeedCount > 0 && model.filledSeedCount < OnboardingModel.seedCount {
                Text("Con tres la primera chispa sale mejor, pero podés seguir y sumar más después.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .alert("No se pudo guardar", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var buttonTitle: LocalizedStringKey {
        let pending = model.seeds.filter { $0.isFilled && !$0.isSaved }.count
        if pending == 0 { return "Continuar" }
        return pending == 1 ? "Guardar idea y seguir" : "Guardar \(pending) ideas y seguir"
    }

    private func saveAndContinue() async {
        do {
            try await model.saveSeeds(api: api)
            model.complete(.seeds)
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct SeedCard: View {
    let index: Int
    @Environment(OnboardingModel.self) private var model
    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var model = model
        let seed = model.seeds[index]
        VStack(alignment: .leading, spacing: Space.s3) {
            HStack {
                Text("Idea \(index + 1)")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Spacer()
                if seed.isSaved {
                    Label("Guardada", systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Palette.success)
                }
            }

            if seed.isSaved {
                Text(seed.trimmedText)
                    .font(.body)
                    .foregroundStyle(Palette.ink)
                LumbreChip(seed.trimmedCategory, systemImage: "tag")
            } else {
                TextField(model.placeholder(forSeedAt: index), text: $model.seeds[index].text, axis: .vertical)
                    .lineLimit(2...6)
                    .font(.body)
                    .focused($isFocused)
                    .padding(Space.s3)
                    .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).strokeBorder(isFocused ? Palette.focusRing : Palette.borderStrong, lineWidth: isFocused ? 2 : 1))
                    .accessibilityLabel(Text("Idea \(index + 1)"))

                VStack(alignment: .leading, spacing: Space.s2) {
                    Text("Categoría")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Palette.inkMuted)
                    TextField("Ej.: Urbanismo", text: Binding(
                        get: { model.seeds[index].category },
                        set: { model.setCategory($0, forSeedAt: index) }
                    ))
                    .font(.body)
                    .textInputAutocapitalization(.sentences)
                    .padding(Space.s3)
                    .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).strokeBorder(Palette.borderStrong, lineWidth: 1))
                    .accessibilityLabel(Text("Categoría de la idea \(index + 1)"))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Space.s2) {
                            ForEach(model.suggestedCategories, id: \.self) { name in
                                let isOn = seed.trimmedCategory.localizedCaseInsensitiveCompare(name) == .orderedSame
                                Button {
                                    model.setCategory(name, forSeedAt: index)
                                } label: {
                                    LumbreChip(name, variant: isOn ? .on : .select)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .scrollClipDisabled()
                    .accessibilityLabel(Text("Categorías sugeridas"))
                }
            }
        }
        .padding(Space.s4)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
    }
}

// MARK: - Hora de la chispa

/// Paso 4: a qué hora llega la chispa (08:00 por defecto).
struct SparkHourStepView: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        @Bindable var model = model
        OnboardingScaffold(step: .sparkHour, title: "¿A qué hora querés tu chispa?", subtitle: "Todos los días, a esta hora, dos de tus ideas chocan y aparece una nueva.") {
            DatePicker("Hora de la chispa", selection: $model.sparkTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.s2)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            Text("La mayoría la elige a la mañana, antes de arrancar el día. La podés cambiar en Perfil.")
                .font(.footnote)
                .foregroundStyle(Palette.inkMuted)
        } footer: {
            Button("Continuar") {
                model.trackSparkHour()
                model.complete(.sparkHour)
            }
            .buttonStyle(.lumbre(.primary, fullWidth: true))
        }
    }
}

// MARK: - Push

/// Paso 5: permiso de notificaciones con contexto. Si dice que no, la chispa espera igual en Hoy.
struct PushStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(AppModel.self) private var appModel
    @Environment(\.api) private var api
    @State private var isRequesting = false
    @State private var finishError: String?

    var body: some View {
        OnboardingScaffold(step: .push, title: "Te avisamos cuando esté lista", subtitle: "Un aviso por día, a la hora que elegiste. Nada más.") {
            VStack(alignment: .leading, spacing: Space.s4) {
                notificationPreview
                Label("Si preferís sin avisos, la chispa te espera igual en Hoy.", systemImage: "sparkles")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
            }
        } footer: {
            Button {
                Task { await allow() }
            } label: {
                if isRequesting || model.isFinishing {
                    ProgressView()
                        .tint(Palette.onAccent)
                        .accessibilityLabel(Text("Guardando"))
                } else {
                    Text("Avisame")
                }
            }
            .buttonStyle(.lumbre(.primary, fullWidth: true))
            .disabled(isRequesting || model.isFinishing)

            Button("Ahora no") {
                Task { await finish() }
            }
            .buttonStyle(.lumbre(.secondary, fullWidth: true))
            .disabled(isRequesting || model.isFinishing)
        }
        .onAppear {
            Analytics.track(.pushPermissionPrompted(context: "onboarding"))
        }
        .alert("No pudimos guardar tu perfil", isPresented: Binding(get: { finishError != nil }, set: { if !$0 { finishError = nil } })) {
            Button("Reintentar") { Task { await finish() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(finishError ?? "")
        }
    }

    /// Cómo se va a ver el aviso, para que se entienda qué se acepta.
    private var notificationPreview: some View {
        HStack(alignment: .top, spacing: Space.s3) {
            Image(systemName: "bell.badge")
                .font(.title3)
                .foregroundStyle(Palette.infoText)
                .frame(width: 36, height: 36)
                .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(verbatim: "Lumbre")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(model.sparkTime, format: .dateTime.hour().minute())
                        .font(.footnote)
                        .foregroundStyle(Palette.inkMuted)
                }
                Text("Tu chispa de hoy está lista")
                    .font(.subheadline)
                Text("Dos neuronas de tu red se conectaron. Entrá a ver qué chispa salió.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkMuted)
            }
            .foregroundStyle(Palette.ink)
        }
        .padding(Space.s4)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Ejemplo de aviso"))
    }

    private func allow() async {
        isRequesting = true
        let result = await PushPermission.request()
        Analytics.track(.pushPermissionResponded(granted: result.granted, systemPromptShown: result.systemPromptShown))
        isRequesting = false
        await finish()
    }

    private func finish() async {
        do {
            let profile = try await model.finish(api: api)
            await SparkReminder.schedule(at: profile.sparkTime)
            appModel.completeOnboarding(with: profile)
        } catch {
            finishError = error.localizedDescription
        }
    }
}

#Preview("Perfil") {
    NavigationStack { ProfileStepView() }
        .environment(OnboardingModel(profile: nil))
        .preferredColorScheme(.light)
}

#Preview("Semillas") {
    let model = OnboardingModel(profile: nil)
    model.profiles = [.software, .business]
    return NavigationStack { SeedsStepView() }
        .environment(model)
        .preferredColorScheme(.light)
}

#Preview("Hora") {
    NavigationStack { SparkHourStepView() }
        .environment(OnboardingModel(profile: nil))
        .preferredColorScheme(.light)
}

#Preview("Push") {
    NavigationStack { PushStepView() }
        .environment(OnboardingModel(profile: nil))
        .environment(AppModel())
        .preferredColorScheme(.light)
}

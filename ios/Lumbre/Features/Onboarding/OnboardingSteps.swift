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
            CreativeProfilePicker(selection: $model.profiles, role: $model.role)
        } footer: {
            Button("Continuar") { model.complete(.profile) }
                .buttonStyle(.lumbre(.primary, fullWidth: true))
                .disabled(model.profiles.isEmpty && model.trimmedRole.isEmpty)
        }
    }
}

// MARK: - Ideas semilla

/// Paso 3: hasta tres ideas con su categoría. Es opcional: se puede saltear y guardarlas después.
struct SeedsStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(\.api) private var api
    @State private var saveError: String?

    var body: some View {
        OnboardingScaffold(step: .seeds, title: "Tus primeras neuronas", subtitle: "Algo que leíste, viste o pensaste. Cada idea que guardás es una neurona, y con estas sale tu primera chispa.") {
            VStack(alignment: .leading, spacing: Space.s4) {
                Label("Mejor si son de temas distintos: así se conectan mundos lejanos. Podés dictarlas con el micrófono del teclado.", systemImage: "lightbulb")
                    .font(.callout)
                    .foregroundStyle(Palette.inkMuted)
                ForEach(model.seeds.indices, id: \.self) { index in
                    SeedCard(index: index)
                }
            }
        } footer: {
            if model.filledSeedCount == 0 {
                Button("Saltear por ahora") { model.complete(.seeds) }
                    .buttonStyle(.lumbre(.secondary, fullWidth: true))
                Text("Podés guardar tus primeras neuronas cuando quieras, desde Capturar.")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkMuted)
                    .multilineTextAlignment(.center)
            } else {
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
                .disabled(model.isSavingSeeds)
            }

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
        return pending == 1 ? "Guardar neurona y seguir" : "Guardar \(pending) neuronas y seguir"
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var isFocused: Bool

    private var isLargeText: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        @Bindable var model = model
        let seed = model.seeds[index]
        VStack(alignment: .leading, spacing: Space.s3) {
            HStack {
                Text("Neurona \(index + 1)")
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
                // Con tamaños de accesibilidad, el ejemplo va arriba y más chico: como placeholder no pasaba de las
                // líneas mínimas y terminaba en "autoorgani-zan sin un je…".
                if isLargeText {
                    Text(model.placeholder(forSeedAt: index))
                        .font(.footnote)
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                TextField(isLargeText ? "" : model.placeholder(forSeedAt: index), text: $model.seeds[index].text, axis: .vertical)
                    .lineLimit(isLargeText ? 3...8 : 2...6)
                    .font(.body)
                    .focused($isFocused)
                    .padding(Space.s3)
                    .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).strokeBorder(isFocused ? Palette.focusRing : Palette.borderStrong, lineWidth: isFocused ? 2 : 1))
                    .accessibilityLabel(Text("Neurona \(index + 1)"))

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
                    .accessibilityLabel(Text("Categoría de la neurona \(index + 1)"))

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
                    // Scrollea de borde a borde de la tarjeta y se corta ahí (antes se salía de la tarjeta).
                    .contentMargins(.horizontal, Space.s4, for: .scrollContent)
                    .padding(.horizontal, -Space.s4)
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

/// Último paso, solo si quiso el aviso: a qué hora llega (08:00 por defecto). Al seguir, termina el onboarding.
struct SparkHourStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(AppModel.self) private var appModel
    @Environment(\.api) private var api
    @State private var finishError: String?

    var body: some View {
        @Bindable var model = model
        OnboardingScaffold(step: .sparkHour, title: "¿A qué hora te avisamos?", subtitle: "Todos los días, a esta hora, te llega el aviso de tu chispa.") {
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
            Button {
                model.trackSparkHour()
                Task { await finish() }
            } label: {
                if model.isFinishing {
                    ProgressView()
                        .tint(Palette.onAccent)
                        .accessibilityLabel(Text("Guardando"))
                } else {
                    Text("Listo")
                }
            }
            .buttonStyle(.lumbre(.primary, fullWidth: true))
            .disabled(model.isFinishing)
        }
        .alert("No pudimos guardar tu perfil", isPresented: Binding(get: { finishError != nil }, set: { if !$0 { finishError = nil } })) {
            Button("Reintentar") { Task { await finish() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(finishError ?? "")
        }
    }

    private func finish() async {
        do {
            let profile = try await model.finish(api: api, lastStep: .sparkHour)
            await SparkReminder.schedule(at: profile.sparkTime)
            appModel.completeOnboarding(with: profile)
        } catch {
            finishError = error.localizedDescription
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// El recuadro del ícono crece con el texto: fijo en 36, con texto grande la campana lo desbordaba.
    @ScaledMetric(relativeTo: .title3) private var iconBox: CGFloat = 36

    var body: some View {
        OnboardingScaffold(step: .push, title: "¿Te avisamos cuando esté lista?", subtitle: "Un aviso por día, cuando sale tu chispa. Nada más.") {
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
        // Con tamaños de accesibilidad, todo en una columna: al lado del ícono y de la hora, "Lumbre" se cortaba
        // por sílabas.
        let isLargeText = dynamicTypeSize.isAccessibilitySize
        let layout = isLargeText
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Space.s2))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Space.s3))
        let header = isLargeText
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout())
        return layout {
            Image(systemName: "bell.badge")
                .font(.title3)
                .foregroundStyle(Palette.infoText)
                .frame(width: iconBox, height: iconBox)
                .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                // Encabeza lo que lee VoiceOver; el resto del aviso se lee entero.
                .accessibilityLabel(Text("Ejemplo de aviso"))
            VStack(alignment: .leading, spacing: 2) {
                header {
                    Text(verbatim: "Lumbre")
                        .font(.subheadline.weight(.semibold))
                    if !isLargeText {
                        Spacer()
                    }
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
    }

    /// Si da el permiso, sigue a elegir la hora; si el sistema lo rechaza, no tiene sentido elegirla y termina.
    private func allow() async {
        isRequesting = true
        let result = await PushPermission.request()
        Analytics.track(.pushPermissionResponded(granted: result.granted, systemPromptShown: result.systemPromptShown))
        isRequesting = false
        if result.granted {
            model.complete(.push)
        } else {
            await finish()
        }
    }

    /// Sin aviso: termina con la hora por defecto (la chispa igual sale y espera en Hoy).
    private func finish() async {
        do {
            let profile = try await model.finish(api: api, lastStep: .push)
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

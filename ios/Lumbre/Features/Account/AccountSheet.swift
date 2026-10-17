import LumbreCore
import LumbreDesign
import SwiftUI

/// Crear la cuenta o entrar a una que ya existe, con un código de 6 dígitos por email (plan.md §4, onboarding).
/// - `.createAccount` (invitado): el mismo usuario pasa a tener email y conserva su red.
/// - `.signIn` ("Ya tengo cuenta"): entra a la cuenta de ese email; lo del invitado de esta sesión no pasa.
/// Apple y Google se suman cuando estén sus credenciales (H1). Con el flag `account_email` apagado se muestra
/// el aviso de antes (`AccountComingSoonSheet`).
struct AccountSheet: View {
    let initialPurpose: EmailCodePurpose
    /// Texto del botón para seguir sin cuenta; nil lo oculta.
    var continueAsGuestTitle: LocalizedStringKey?
    var onContinueAsGuest: () -> Void = {}
    /// Se llama con el perfil de la cuenta, después de cerrar la sheet.
    var onFinished: (Profile, EmailCodePurpose) -> Void

    @Environment(\.api) private var api
    @Environment(\.dismiss) private var dismiss
    @State private var purpose: EmailCodePurpose
    @State private var email = ""
    @State private var code = ""
    /// Email al que se mandó el código: con él, la sheet pasa al paso del código.
    @State private var sentTo: String?
    @State private var isWorking = false
    @State private var errorMessage: String?
    /// Un invitado quiso crear la cuenta con un email que ya tiene una.
    @State private var emailInUse = false
    @State private var resentNotice = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, code }

    init(purpose: EmailCodePurpose, continueAsGuestTitle: LocalizedStringKey? = nil, onContinueAsGuest: @escaping () -> Void = {},
         onFinished: @escaping (Profile, EmailCodePurpose) -> Void) {
        initialPurpose = purpose
        self.continueAsGuestTitle = continueAsGuestTitle
        self.onContinueAsGuest = onContinueAsGuest
        self.onFinished = onFinished
        _purpose = State(initialValue: purpose)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.s5) {
                    header
                    if let sentTo {
                        codeStep(sentTo)
                    } else {
                        emailStep
                    }
                    if let errorMessage {
                        ActionNotice(text: "\(errorMessage)", symbol: "exclamationmark.triangle.fill", color: Palette.danger)
                            .accessibilityAddTraits(.isStaticText)
                    }
                    if emailInUse { emailInUseNotice }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.s4)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { footer }
            .background(Palette.surface)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .disabled(isWorking)
                }
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(Radius.lg)
        .interactiveDismissDisabled(isWorking)
        .onAppear {
            Analytics.screen(purpose == .createAccount ? "account_create" : "account_sign_in")
            focusedField = .email
        }
    }

    // MARK: Partes

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text(purpose == .createAccount ? "Creá tu cuenta" : "Entrá a tu cuenta")
                .lumbreDisplay(.title1)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            Text(purpose == .createAccount
                 ? "Tu red queda a salvo aunque cambies o pierdas el teléfono. Todo lo que guardaste como invitado pasa a tu cuenta."
                 : "Te mandamos un código a tu email, sin contraseñas. Si todavía no tenés cuenta, la creamos con ese email.")
                .font(.body)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("Email")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Palette.inkMuted)
            LumbreTextField("Tu email", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.send)
                .focused($focusedField, equals: .email)
                .onSubmit { Task { await sendCode() } }
                .accessibilityLabel(Text("Email"))
            Text("Pronto también con Apple y Google.")
                .font(.footnote)
                .foregroundStyle(Palette.inkMuted)
        }
    }

    private func codeStep(_ address: String) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Te mandamos un código de 6 dígitos a \(address). Escribilo acá o tocá el link del mail en este teléfono.")
                .font(.callout)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            LumbreTextField("Código", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.title3.monospacedDigit())
                .focused($focusedField, equals: .code)
                .accessibilityLabel(Text("Código de 6 dígitos"))
                .onChange(of: code) { _, value in
                    if EmailAccount.normalizedCode(value) != nil { Task { await verify() } }
                }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.s4) { codeActions }
                VStack(alignment: .leading, spacing: Space.s1) { codeActions }
            }
            if resentNotice {
                ActionNotice(text: "Te mandamos otro código.")
            }
        }
    }

    @ViewBuilder
    private var codeActions: some View {
        Button("Mandar otro código") { Task { await sendCode(resend: true) } }
            .buttonStyle(.lumbre(.ghost))
            .disabled(isWorking)
        Button("Cambiar el email") {
            sentTo = nil
            code = ""
            errorMessage = nil
            resentNotice = false
            focusedField = .email
        }
        .buttonStyle(.lumbre(.ghost))
        .disabled(isWorking)
    }

    private var emailInUseNotice: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Si entrás con esa cuenta, lo que guardaste como invitado en este teléfono no pasa a ella.")
                .font(.callout)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Button("Entrar con ese email") {
                purpose = .signIn
                emailInUse = false
                errorMessage = nil
                Task { await sendCode() }
            }
            .buttonStyle(.lumbre(.secondary))
        }
        .padding(Space.s4)
        .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private var footer: some View {
        VStack(spacing: Space.s2) {
            Button {
                Task {
                    if sentTo == nil { await sendCode() } else { await verify() }
                }
            } label: {
                if isWorking {
                    ProgressView()
                        .tint(Palette.onAccent)
                        .accessibilityLabel(Text("Esperando"))
                } else {
                    Text(sentTo == nil ? "Mandarme el código" : (purpose == .createAccount ? "Crear cuenta" : "Entrar"))
                }
            }
            .buttonStyle(.lumbre(.primary, fullWidth: true))
            .disabled(isWorking || (sentTo == nil ? email.trimmingCharacters(in: .whitespaces).isEmpty : EmailAccount.normalizedCode(code) == nil))

            if let continueAsGuestTitle, sentTo == nil {
                Button(continueAsGuestTitle) {
                    dismiss()
                    onContinueAsGuest()
                }
                .buttonStyle(.lumbre(.secondary, fullWidth: true))
                .disabled(isWorking)
            }
        }
        .padding(.horizontal, Space.s4)
        .padding(.top, Space.s3)
        .padding(.bottom, Space.s2)
        .background(Palette.surface)
    }

    // MARK: Acciones

    private func sendCode(resend: Bool = false) async {
        guard !isWorking else { return }
        let address = sentTo ?? email
        guard let normalized = EmailAccount.normalized(address) else {
            show(LumbreAPIError.invalidEmail)
            return
        }
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil
        emailInUse = false
        do {
            try await api.requestEmailCode(normalized, purpose: purpose)
            sentTo = normalized
            resentNotice = resend
            code = ""
            focusedField = .code
            AccessibilityNotification.Announcement(String(localized: "Te mandamos un código a tu email.")).post()
        } catch LumbreAPIError.emailInUse {
            emailInUse = true
            show(LumbreAPIError.emailInUse)
        } catch {
            show(error)
        }
    }

    private func verify() async {
        guard !isWorking, let sentTo else { return }
        isWorking = true
        defer { isWorking = false }
        errorMessage = nil
        do {
            let profile = try await api.verifyEmailCode(code, email: sentTo, purpose: purpose)
            if purpose == .signIn { Analytics.track(.signedIn(method: "email")) }
            let purpose = purpose
            dismiss()
            onFinished(profile, purpose)
        } catch {
            code = ""
            show(error)
        }
    }

    private func show(_ error: Error) {
        let message = (error as? LumbreAPIError)?.errorDescription ?? LumbreAPIError.unexpected.errorDescription ?? ""
        errorMessage = message
        Analytics.track(.errorShown(screen: "account", code: (error as? LumbreAPIError)?.analyticsCode ?? "unexpected"))
        AccessibilityNotification.Announcement(message).post()
    }
}

/// La sheet de crear cuenta para un invitado, desde Perfil o cuando algo la pide (`appModel.presentAccount`).
/// Con el flag `account_email` apagado, el aviso de que las cuentas llegan pronto.
struct CreateAccountSheet: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        if FeatureFlag.emailAccount.isEnabled {
            AccountSheet(purpose: .createAccount) { profile, purpose in
                appModel.accountChanged(to: profile, purpose: purpose)
            }
        } else {
            AccountComingSoonSheet(continueTitle: "Entendido")
        }
    }
}

#Preview("Crear cuenta") {
    Color.clear.sheet(isPresented: .constant(true)) {
        AccountSheet(purpose: .createAccount) { _, _ in }
    }
    .preferredColorScheme(.light)
    .tint(Palette.ink)
}

#Preview("Entrar") {
    Color.clear.sheet(isPresented: .constant(true)) {
        AccountSheet(purpose: .signIn, continueAsGuestTitle: "Seguir como invitado") { _, _ in }
    }
    .preferredColorScheme(.light)
    .tint(Palette.ink)
}

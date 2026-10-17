import Foundation

/// Para qué se pide el código del email.
public enum EmailCodePurpose: String, Sendable, Equatable {
    /// El invitado crea su cuenta: el mismo usuario pasa a tener email y conserva todo.
    case createAccount = "create_account"
    /// Entra a una cuenta que ya existe (o la crea). Lo del invitado de esta sesión no pasa a esa cuenta.
    case signIn = "sign_in"
}

/// Validación local del email y del código, antes de pedirle nada al servidor.
public enum EmailAccount {
    /// URL a la que vuelve el link del email. Tiene que estar en las Redirect URLs de Auth (`backend/README.md`, H14).
    public static let callbackURL = URL(string: "lumbre://auth-callback")!

    /// Normaliza (sin espacios, en minúscula) y devuelve nil si no parece un email.
    public static func normalized(_ email: String) -> String? {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard value.count <= 254, parts.count == 2,
              !parts[0].isEmpty, !parts[0].contains(" "),
              parts[1].contains("."), !parts[1].hasPrefix("."), !parts[1].hasSuffix("."), !parts[1].contains(" ")
        else { return nil }
        return value
    }

    /// Solo los dígitos; nil si no son 6.
    public static func normalizedCode(_ code: String) -> String? {
        let digits = code.filter(\.isASCII).filter(\.isNumber)
        return digits.count == 6 ? digits : nil
    }

    /// Si la URL es la vuelta del link del email.
    public static func isCallback(_ url: URL) -> Bool {
        url.scheme == callbackURL.scheme && url.host() == callbackURL.host()
    }
}

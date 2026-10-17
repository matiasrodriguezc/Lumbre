import AppIntents

/// Atajos de Siri y Spotlight (paso 55). Las frases tienen que nombrar la app; las traducciones están en
/// `AppShortcuts.xcstrings`. La idea y la categoría las pide Siri (un texto libre no puede ir en la frase).
struct LumbreShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SaveIdeaIntent(),
            phrases: [
                "Guardar una idea en \(.applicationName)",
                "Guardá una idea en \(.applicationName)",
                "Anotar una idea en \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource("Guardar una idea", table: "Extensions"),
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: OpenTodaySparkIntent(),
            phrases: [
                "Ver la chispa de hoy en \(.applicationName)",
                "Mostrame la chispa de \(.applicationName)",
                "Qué chispa salió hoy en \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource("Chispa de hoy", table: "Extensions"),
            systemImageName: "sparkle"
        )
        AppShortcut(
            intent: OpenCaptureIntent(),
            phrases: [
                "Capturar en \(.applicationName)",
                "Abrir Capturar en \(.applicationName)",
            ],
            shortTitle: LocalizedStringResource("Capturar", table: "Extensions"),
            systemImageName: "square.and.pencil"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .grayBlue
}

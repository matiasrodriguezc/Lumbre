import LumbreDesign
import SwiftUI

struct ProfileView: View {
    @AppStorage("theme") private var theme: ThemePreference = .dark
    @AppStorage("sparkHour") private var sparkHour: Double = 8 * 3_600
    @State private var isConfirmingDeletion = false

    var body: some View {
        NavigationStack {
            List {
                Section("Tu perfil") {
                    LabeledContent("Perfil creativo", value: "Software y apps, Curiosidad libre")
                    DatePicker("Hora de la chispa", selection: sparkTime, displayedComponents: .hourAndMinute)
                }
                .listRowBackground(Palette.surface)

                Section("Apariencia") {
                    Picker("Tema", selection: $theme) {
                        ForEach(ThemePreference.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                }
                .listRowBackground(Palette.surface)

                Section("Suscripción") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lumbre Pro")
                                .font(.headline)
                            Text("Hasta 10 chispas por día y el planificador")
                                .font(.footnote)
                                .foregroundStyle(Palette.inkMuted)
                        }
                        Spacer()
                        Text("Pro")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.onPro)
                            .padding(.horizontal, Space.s2)
                            .padding(.vertical, 2)
                            .background(Palette.pro, in: Capsule())
                    }
                    Button("Probar 7 días gratis") {}
                        .foregroundStyle(Palette.proText)
                }
                .listRowBackground(Palette.surface)

                Section("Privacidad") {
                    Button("Exportar mis datos") {}
                        .foregroundStyle(Palette.ink)
                    Button(role: .destructive) {
                        isConfirmingDeletion = true
                    } label: {
                        Label("Borrar cuenta", systemImage: "trash")
                            .foregroundStyle(Palette.danger)
                    }
                }
                .listRowBackground(Palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.bg)
            .navigationTitle("Perfil")
            .confirmationDialog("¿Borrar tu cuenta?", isPresented: $isConfirmingDeletion, titleVisibility: .visible) {
                Button("Borrar cuenta", role: .destructive) {}
            } message: {
                Text("Se borran todos tus conceptos, chispas y proyectos. No se puede deshacer.")
            }
        }
    }

    private var sparkTime: Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: .now).addingTimeInterval(sparkHour) },
            set: { sparkHour = $0.timeIntervalSince(Calendar.current.startOfDay(for: $0)) }
        )
    }
}

extension ThemePreference {
    var label: LocalizedStringKey {
        switch self {
        case .dark: return "Oscuro"
        case .light: return "Claro"
        case .system: return "Como el sistema"
        }
    }
}

#Preview {
    ProfileView()
        .preferredColorScheme(.dark)
}

import LumbreDesign
import SwiftUI

enum AppTab: Hashable {
    case today, vault, projects, profile
    /// No es un destino: abre la sheet de Capturar.
    case capture
}

/// Barra flotante con los cuatro destinos y el botón Capturar separado a la derecha.
/// En iOS 26 el sistema ubica la pestaña con `role: .search` aparte, en su propio círculo de Liquid Glass;
/// acá se usa ese lugar para Capturar y la selección se intercepta para abrir la sheet.
struct RootView: View {
    @State private var selection: AppTab = .today
    @State private var isCapturing = false
    @State private var dataVersion = 0

    var body: some View {
        tabs
            .environment(\.dataVersion, dataVersion)
            .sheet(isPresented: $isCapturing) {
                CaptureSheet { dataVersion += 1 }
            }
    }

    private var selectionBinding: Binding<AppTab> {
        Binding(
            get: { selection },
            set: { newValue in
                if newValue == .capture {
                    isCapturing = true
                } else {
                    selection = newValue
                }
            }
        )
    }

    @ViewBuilder
    private var tabs: some View {
        if #available(iOS 18, *) {
            TabView(selection: selectionBinding) {
                Tab("Hoy", systemImage: "sparkles", value: .today) { TodayView() }
                Tab("Bóveda", systemImage: "square.stack.3d.up", value: .vault) { VaultView() }
                Tab("Proyectos", systemImage: "square.grid.2x2", value: .projects) { ProjectsView() }
                Tab("Perfil", systemImage: "person.crop.circle", value: .profile) { ProfileView() }
                Tab("Capturar", systemImage: "plus", value: .capture, role: .search) { Color.clear }
            }
            .modifier(MinimizeTabBarOnScroll())
        } else {
            TabView(selection: selectionBinding) {
                TodayView().tabItem { Label("Hoy", systemImage: "sparkles") }.tag(AppTab.today)
                VaultView().tabItem { Label("Bóveda", systemImage: "square.stack.3d.up") }.tag(AppTab.vault)
                ProjectsView().tabItem { Label("Proyectos", systemImage: "square.grid.2x2") }.tag(AppTab.projects)
                ProfileView().tabItem { Label("Perfil", systemImage: "person.crop.circle") }.tag(AppTab.profile)
                Color.clear.tabItem { Label("Capturar", systemImage: "plus") }.tag(AppTab.capture)
            }
        }
    }
}

private struct MinimizeTabBarOnScroll: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
        .tint(Palette.accentText)
}

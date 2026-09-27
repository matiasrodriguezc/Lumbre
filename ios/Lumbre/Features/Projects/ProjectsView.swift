import LumbreDesign
import SwiftUI

struct ProjectsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Todavía no hay proyectos",
                systemImage: "square.grid.2x2",
                description: Text("Guardá una idea desde Hoy y elegí dónde sumarla para empezar tu primer proyecto.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.bg)
            .navigationTitle("Proyectos")
        }
    }
}

#Preview {
    ProjectsView()
        .preferredColorScheme(.dark)
}

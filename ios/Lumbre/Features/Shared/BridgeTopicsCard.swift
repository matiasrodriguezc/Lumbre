import LumbreCore
import LumbreDesign
import SwiftUI

/// Temas puente (paso 92, solo Pro, flag `bridge_topics`): dos dominios fuertes de la Red que casi no se cruzaron
/// y 2 o 3 temas para leer que los unan. Solo temas, nunca links: tocar uno ofrece buscarlo en la web o copiarlo.
/// Va en la Red y en Hoy cuando quedan pocos pares buenos.
struct BridgeTopicsCard: View {
    let bridge: BridgeTopics
    /// `vault` o `today`, para los eventos.
    let screen: String

    @Environment(\.openURL) private var openURL
    @State private var copiedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            HStack(alignment: .firstTextBaseline, spacing: Space.s2) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(Palette.ink)
                    .accessibilityHidden(true)
                Text("Temas puente")
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(intro)
                .font(.footnote)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(bridge.topics.enumerated()), id: \.offset) { index, topic in
                    if index > 0 { Divider().overlay(Palette.border) }
                    row(topic, index: index)
                }
            }
        }
        .padding(Space.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private var intro: String {
        let a = bridge.domains.first?.name ?? ""
        let b = bridge.domains.dropFirst().first?.name ?? ""
        return String(localized: "Guardaste mucho de \(a) y de \(b), pero casi nunca se cruzaron. Para leer y unirlos:")
    }

    private func row(_ topic: BridgeTopic, index: Int) -> some View {
        Menu {
            Button {
                search(topic, index: index)
            } label: {
                Label("Buscar en la web", systemImage: "magnifyingglass")
            }
            Button {
                copy(topic, index: index)
            } label: {
                Label("Copiar", systemImage: "doc.on.doc")
            }
        } label: {
            HStack(alignment: .center, spacing: Space.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text(copiedIndex == index ? String(localized: "Copiado") : topic.why)
                        .font(.footnote)
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: copiedIndex == index ? "checkmark" : "magnifyingglass")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Palette.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Space.s3)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Buscar el tema en la web o copiarlo"))
    }

    /// Abre la búsqueda del navegador con el buscador que eligió la persona. Si no se puede, lo copia.
    private func search(_ topic: BridgeTopic, index: Int) {
        Analytics.track(.bridgeTopicTapped(screen: screen, index: index + 1, action: "search"))
        var components = URLComponents()
        components.scheme = "x-web-search"
        components.host = ""
        components.percentEncodedQuery = topic.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        guard let url = components.url else { return copy(topic, index: index, track: false) }
        openURL(url) { accepted in
            if !accepted { copy(topic, index: index, track: false) }
        }
    }

    private func copy(_ topic: BridgeTopic, index: Int, track: Bool = true) {
        if track { Analytics.track(.bridgeTopicTapped(screen: screen, index: index + 1, action: "copy")) }
        UIPasteboard.general.string = topic.title
        copiedIndex = index
        AccessibilityNotification.Announcement(String(localized: "Copiado")).post()
        Task {
            try? await Task.sleep(for: .seconds(2))
            if copiedIndex == index { copiedIndex = nil }
        }
    }
}

extension BridgeTopicsCard {
    /// Manda `bridge_topics_shown` una vez por sugerencia y pantalla.
    static func trackShown(_ bridge: BridgeTopics, screen: String, alreadyTracked: inout BridgeTopics.ID?) {
        guard alreadyTracked != bridge.id else { return }
        alreadyTracked = bridge.id
        Analytics.track(.bridgeTopicsShown(screen: screen, topicsCount: bridge.topics.count,
                                           domainA: bridge.domains.first?.slug ?? "", domainB: bridge.domains.dropFirst().first?.slug ?? ""))
    }
}

#Preview {
    BridgeTopicsCard(bridge: BridgeTopics(
        domains: [MockData.domains[7], MockData.domains[1]],
        topics: [BridgeTopic(title: "Algoritmos evolutivos", why: "Programas que mejoran por selección y mutación, como las especies."),
                 BridgeTopic(title: "Bioinformática", why: "Software y datos para leer genomas y proteínas."),
                 BridgeTopic(title: "Computación con ADN", why: "Usar moléculas de ADN para guardar datos y hacer cálculos.")]
    ), screen: "vault")
    .padding()
    .background(Palette.bg)
}

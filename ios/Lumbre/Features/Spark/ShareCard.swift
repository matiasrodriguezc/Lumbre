import LumbreCore
import LumbreDesign
import SwiftUI
import UniformTypeIdentifiers

/// Los formatos de la tarjeta (design/compartir). Historias es el de siempre; feed es la segunda opción (flag `share_card_feed`).
enum ShareCardFormat: String, CaseIterable, Identifiable {
    /// 1080 × 1920, para historias de Instagram, TikTok y WhatsApp.
    case story
    /// 1080 × 1350, para publicaciones: sin interfaz encima, márgenes parejos.
    case feed

    var id: String { rawValue }

    var size: CGSize {
        switch self {
        case .story: CGSize(width: 1080, height: 1920)
        case .feed: CGSize(width: 1080, height: 1350)
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .story: "Para historias"
        case .feed: "Para publicaciones"
        }
    }
}

/// Tarjeta vertical para compartir: la red dormida arriba, las dos neuronas con la sinapsis encendida,
/// la idea y la firma, sobre el gris de marca. Fija en el tema gris, así sale igual con cualquier tema.
struct ShareCardView: View {
    let spark: Spark
    var format: ShareCardFormat = .story
    /// Zonas seguras de design/compartir (flag `share_card_safe_zones`): margen de abajo de 340 para que la firma
    /// no quede bajo la barra de responder de Instagram ni la de abajo de TikTok, y la categoría en una sola línea.
    var safeZones = FeatureFlag.shareCardSafeZones.isEnabled

    /// Las medidas que cambian entre formatos (px a escala 1, de design/compartir/tarjeta.html).
    private struct Metrics {
        let top, bottom, network, pairGap, synapse, synapseGap, title, titleGap, body: CGFloat
        let bodyLines: Int
        let signatureGap: CGFloat
    }

    private var metrics: Metrics {
        switch format {
        case .story:
            // Márgenes seguros de las historias: arriba y abajo la app de Instagram pone su interfaz.
            Metrics(top: 250, bottom: safeZones ? 340 : 200, network: 1000, pairGap: 40, synapse: 880, synapseGap: 96,
                    title: 104, titleGap: 48, body: 46, bodyLines: 7, signatureGap: 96)
        case .feed:
            Metrics(top: 120, bottom: 112, network: 700, pairGap: 28, synapse: 760, synapseGap: 64,
                    title: 88, titleGap: 36, body: 40, bodyLines: 5, signatureGap: 72)
        }
    }

    var body: some View {
        let m = metrics
        return content(m)
            .padding(.horizontal, 96)
            .padding(.top, m.top)
            .padding(.bottom, m.bottom)
            .frame(width: format.size.width, height: format.size.height, alignment: .topLeading)
            .background(alignment: .top) {
                ZStack(alignment: .top) {
                    Palette.gray
                    NeuralNetworkBackground(.tall)
                        .frame(height: m.network)
                        .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
                }
            }
            .environment(\.colorScheme, .light)
    }

    private func content(_ m: Metrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // El bloque de la chispa va centrado entre el borde de arriba y la firma.
            Spacer(minLength: 0)
            HStack(alignment: .top, spacing: 48) {
                concept(spark.conceptA, alignment: .leading)
                concept(spark.conceptB, alignment: .trailing)
            }
            .padding(.bottom, m.pairGap)

            Synapse(.lit, full: true)
                .frame(width: m.synapse)
                .frame(maxWidth: .infinity)
                .padding(.bottom, m.synapseGap)

            Text(spark.title)
                .font(Font(LumbreFont.uiDisplay(.sparkHero, size: m.title) as CTFont))
                .foregroundStyle(Palette.neuron)
                .lineSpacing(6)
                .lineLimit(4)
                .minimumScaleFactor(0.6)
                .padding(.bottom, m.titleGap)

            Text(spark.body)
                .font(.system(size: m.body, weight: .regular))
                .foregroundStyle(Palette.neuron.opacity(0.85))
                .lineSpacing(12)
                .lineLimit(m.bodyLines)
                .minimumScaleFactor(0.7)

            Spacer(minLength: m.signatureGap)

            HStack(alignment: .center, spacing: 24) {
                LumbreMark(.long).frame(width: 150)
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(verbatim: "Lumbre")
                        .font(Font(LumbreFont.uiDisplay(.title1, size: 72) as CTFont))
                        .foregroundStyle(Palette.neuron)
                    Circle()
                        .fill(Palette.spark)
                        .frame(width: 18, height: 18)
                }
                Spacer(minLength: 0)
                Text("Donde se encienden las ideas")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Palette.neuron.opacity(0.65))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func concept(_ concept: Concept, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 12) {
            Text(concept.categoryName)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Palette.neuron.opacity(0.65))
                // Una categoría larga no empuja el título de su neurona ni desalinea las dos columnas.
                .lineLimit(safeZones ? 1 : nil)
            Text(concept.title)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Palette.neuron)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    /// PNG del tamaño del formato (1080 × 1920 o 1080 × 1350).
    @MainActor
    static func render(_ spark: Spark, format: ShareCardFormat = .story) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(spark: spark, format: format))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(format.size)
        return renderer.uiImage
    }
}

/// La imagen para la hoja de compartir. Cuenta `spark_shared` cuando el destino la pide.
struct ShareCardImage: Transferable {
    let png: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { image in
            Analytics.track(.sparkShared(activityType: nil))
            return image.png
        }
        .suggestedFileName(String(localized: "Lumbre-chispa.png"))
    }
}

/// Vista previa de la tarjeta antes de compartirla.
struct ShareCardSheet: View {
    let spark: Spark

    @Environment(\.dismiss) private var dismiss
    @State private var format: ShareCardFormat = .story
    @State private var image: UIImage?
    @State private var png: Data?
    @State private var renderFailed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Space.s5) {
                if FeatureFlag.shareCardFeed.isEnabled {
                    Picker("Formato", selection: $format) {
                        ForEach(ShareCardFormat.allCases) { format in
                            Text(format.label).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                // La vista previa es la misma vista que se renderiza, achicada para que entre.
                GeometryReader { proxy in
                    let size = format.size
                    let scale = min(proxy.size.width / size.width, proxy.size.height / size.height)
                    ShareCardView(spark: spark, format: format)
                        .scaleEffect(scale)
                        .frame(width: size.width * scale, height: size.height * scale)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
                        .accessibilityHidden(true)
                        // VoiceOver la lee como una imagen. El elemento va encima y no en la tarjeta achicada: con
                        // `scaleEffect`, el recuadro del foco quedaba del tamaño real y corrido hacia arriba.
                        .overlay {
                            Color.clear
                                .accessibilityElement()
                                .accessibilityLabel(Text(spark.accessibilitySummary))
                                .accessibilityAddTraits(.isImage)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if let png, let image {
                    ShareLink(
                        item: ShareCardImage(png: png),
                        preview: SharePreview(spark.title, image: Image(uiImage: image))
                    ) {
                        Label("Compartir imagen", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.lumbre(.primary, fullWidth: true))
                } else if renderFailed {
                    ActionNotice(text: "No pudimos armar la imagen. Probá de nuevo.", symbol: "exclamationmark.triangle.fill", color: Palette.danger)
                } else {
                    ProgressView()
                        .frame(minHeight: 48)
                }
            }
            .padding(Space.s4)
            .background(Palette.surface)
            .navigationTitle("Tarjeta para compartir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onAppear { Analytics.screen("share_card") }
            .task(id: format) {
                // Cada formato se arma de nuevo; mientras tanto no se puede compartir el anterior.
                image = nil
                png = nil
                renderFailed = false
                guard let rendered = ShareCardView.render(spark, format: format) else {
                    renderFailed = true
                    return
                }
                image = rendered
                png = rendered.pngData()
                Analytics.track(.shareCardCreated(mode: spark.mode, format: format.rawValue))
            }
        }
        .presentationDetents([.large])
    }
}

#Preview("Tarjeta") {
    ShareCardView(spark: MockData.todaySpark)
        .scaleEffect(0.3)
        .frame(width: 324, height: 576)
}

#Preview("Sheet") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ShareCardSheet(spark: MockData.recentSparks[0])
        }
}

#Preview("Tarjeta feed") {
    ShareCardView(spark: MockData.todaySpark, format: .feed)
        .scaleEffect(0.3)
        .frame(width: 324, height: 405)
}

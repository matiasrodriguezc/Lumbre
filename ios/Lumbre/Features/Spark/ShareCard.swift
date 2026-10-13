import LumbreCore
import LumbreDesign
import SwiftUI
import UniformTypeIdentifiers

/// Tarjeta vertical para historias (1080 × 1920): la chispa y la marca sobre `night`.
/// Usa solo colores fijos de marca, así sale igual con el tema claro o el oscuro.
struct ShareCardView: View {
    let spark: Spark

    static let size = CGSize(width: 1080, height: 1920)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SparkStar()
                .fill(Palette.spark)
                .frame(width: 88, height: 88)
                .shadow(color: Palette.spark.opacity(0.55), radius: 36)
                .padding(.bottom, 72)

            Text(spark.title)
                .font(Font(LumbreFont.uiDisplay(.sparkHero, size: 104) as CTFont))
                .foregroundStyle(Palette.cream)
                .lineSpacing(6)
                .lineLimit(4)
                .minimumScaleFactor(0.6)
                .padding(.bottom, 48)

            Text(spark.body)
                .font(.system(size: 46, weight: .regular))
                .foregroundStyle(Palette.cream.opacity(0.88))
                .lineSpacing(12)
                .lineLimit(7)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 64)

            VStack(spacing: 28) {
                concept(spark.conceptA)
                Text("×")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(Palette.cream.opacity(0.6))
                concept(spark.conceptB)
            }

            Spacer(minLength: 64)

            HStack(alignment: .lastTextBaseline, spacing: 20) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(verbatim: "Lumbre")
                        .font(Font(LumbreFont.uiDisplay(.title1, size: 72) as CTFont))
                        .foregroundStyle(Palette.cream)
                    Circle()
                        .fill(Palette.spark)
                        .frame(width: 18, height: 18)
                }
                Spacer(minLength: 0)
                Text("Donde se encienden las ideas")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Palette.cream.opacity(0.7))
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 96)
        .padding(.top, 160)
        .padding(.bottom, 120)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(Palette.night)
        .environment(\.colorScheme, .dark)
    }

    private func concept(_ concept: Concept) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(concept.categoryName, systemImage: concept.categorySymbol)
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(Palette.cream.opacity(0.7))
            Text(concept.title)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Palette.cream)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(40)
        .background {
            RoundedRectangle(cornerRadius: 40, style: .continuous).fill(Palette.cream.opacity(0.08))
        }
        .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous).strokeBorder(Palette.cream.opacity(0.14), lineWidth: 2))
    }

    /// PNG de 1080 × 1920.
    @MainActor
    static func render(_ spark: Spark) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(spark: spark))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(size)
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
        .suggestedFileName("Lumbre-chispa.png")
    }
}

/// Vista previa de la tarjeta antes de compartirla.
struct ShareCardSheet: View {
    let spark: Spark

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var png: Data?
    @State private var renderFailed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Space.s5) {
                // La vista previa es la misma vista que se renderiza, achicada para que entre.
                GeometryReader { proxy in
                    let size = ShareCardView.size
                    let scale = min(proxy.size.width / size.width, proxy.size.height / size.height)
                    ShareCardView(spark: spark)
                        .scaleEffect(scale)
                        .frame(width: size.width * scale, height: size.height * scale)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(spark.accessibilitySummary))
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
            .task {
                guard image == nil else { return }
                guard let rendered = ShareCardView.render(spark) else {
                    renderFailed = true
                    return
                }
                image = rendered
                png = rendered.pngData()
                Analytics.track(.shareCardCreated(mode: spark.mode))
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

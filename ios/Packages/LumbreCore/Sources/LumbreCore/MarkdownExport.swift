import Foundation

/// Export a Markdown (plan.md §4): lo mismo en free y en Pro.
public enum MarkdownExport {
    /// Un proyecto con sus chispas, los dos conceptos de cada una y lo que salió del planificador.
    public static func project(name: String, sparks: [Spark], plans: [Spark.ID: [PlannerMessage]]) -> String {
        var lines = ["# \(name)", ""]
        if sparks.isEmpty {
            lines.append(String(localized: "Todavía no hay ideas en este circuito."))
        }
        for spark in sparks {
            lines.append(contentsOf: self.spark(spark, level: 2))
            if let messages = plans[spark.id], !messages.isEmpty {
                lines.append("### " + String(localized: "Plan"))
                lines.append("")
                for message in messages {
                    let who = message.role == .user ? String(localized: "Yo") : "Lumbre"
                    lines.append("**\(who):** \(message.content)")
                    lines.append("")
                }
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Una chispa como sección de Markdown.
    public static func spark(_ spark: Spark, level: Int = 1) -> [String] {
        let hashes = String(repeating: "#", count: level)
        var lines = ["\(hashes) \(spark.title)", "", spark.body, ""]
        for concept in [spark.conceptA, spark.conceptB] {
            var line = "- **\(concept.title)**"
            if let category = concept.category?.name { line += " (\(category))" }
            line += ": \(concept.thesis)"
            if let url = concept.sourceURL { line += " [\(concept.sourceTitle ?? url.host() ?? url.absoluteString)](\(url.absoluteString))" }
            lines.append(line)
        }
        lines.append("")
        return lines
    }
}

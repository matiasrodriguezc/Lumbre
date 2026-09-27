import Foundation

/// Lo que las pantallas le piden al backend. Hoy lo implementa `MockLumbreAPI`;
/// en el paso 43 se suma el cliente real generado desde el contrato OpenAPI.
public protocol LumbreAPI: Sendable {
    func todaySpark() async throws -> Spark?
    func sparkQuota() async throws -> SparkQuota
    func recentSparks() async throws -> [Spark]
    func concepts() async throws -> [Concept]
    func domains() async throws -> [Domain]
    func saveSpark(id: Spark.ID) async throws
    func sendFeedback(sparkID: Spark.ID, feedback: SparkFeedback) async throws
    func capture(text: String, distill: Bool) async throws -> Concept
}

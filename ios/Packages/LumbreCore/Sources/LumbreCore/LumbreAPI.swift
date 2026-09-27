import Foundation

/// Lo que las pantallas le piden al backend. Hoy lo implementa `MockLumbreAPI`;
/// en el paso 43 se suma el cliente real generado desde el contrato OpenAPI.
public protocol LumbreAPI: Sendable {
    func todaySpark() async throws -> Spark?
    func sparkQuota() async throws -> SparkQuota
    func recentSparks() async throws -> [Spark]
    func concepts() async throws -> [Concept]
    /// Categorías del usuario, en orden alfabético. Un usuario nuevo no tiene ninguna.
    func categories() async throws -> [Category]
    func saveSpark(id: Spark.ID) async throws
    func sendFeedback(sparkID: Spark.ID, feedback: SparkFeedback) async throws
    /// Guarda un concepto en la categoría indicada; si no existe, la crea.
    func capture(thesis: String, category: String, source: CaptureSource) async throws -> CaptureResult
    /// Cierra la sesión en este dispositivo.
    func signOut() async throws
}

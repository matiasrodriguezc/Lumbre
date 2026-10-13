import Foundation
import os
import StoreKit
import SwiftUI

/// Período de un plan de Lumbre Pro. El `rawValue` es el `product` de `purchase_started`.
enum PlanPeriod: String, Sendable, CaseIterable {
    case monthly, annual
}

/// Un plan tal como lo devuelve la tienda: el precio siempre viene localizado de ahí, nunca escrito a mano.
struct PlanOffer: Identifiable, Hashable, Sendable {
    let id: String
    let period: PlanPeriod
    /// Precio localizado ("US$ 6,99").
    let displayPrice: String
    let price: Decimal
    let currencyCode: String
    /// Días de prueba gratis, si la cuenta todavía puede usarlos.
    let trialDays: Int?

    /// Precio por mes del anual ("US$ 4,17").
    var monthlyEquivalent: String {
        let perMonth = period == .annual ? price / 12 : price
        return perMonth.formatted(.currency(code: currencyCode))
    }
}

enum PurchaseOutcome: Sendable, Equatable {
    case purchased
    /// Espera una aprobación (Ask to Buy o un método de pago pendiente).
    case pending
    case cancelled
}

enum PurchaseError: LocalizedError {
    case productsUnavailable
    case unverified

    var errorDescription: String? {
        switch self {
        case .productsUnavailable: String(localized: "No pudimos cargar los planes. Revisá tu conexión y probá de nuevo.")
        case .unverified: String(localized: "La tienda no pudo verificar la compra. Probá de nuevo o tocá Restaurar compras.")
        }
    }
}

/// Compras de Lumbre Pro. Hoy es StoreKit 2 directo; cuando exista RevenueCat (paso 54) lo reemplaza
/// otra implementación de este mismo protocolo y el plan lo actualiza su webhook.
protocol PurchaseService: Sendable {
    func offers() async throws -> [PlanOffer]
    func purchase(_ offer: PlanOffer) async throws -> PurchaseOutcome
    /// Sincroniza con la tienda. Devuelve si encontró una suscripción activa.
    func restore() async throws -> Bool
    func hasActiveSubscription() async -> Bool
    /// Termina las transacciones que llegan fuera de la pantalla (renovaciones, Ask to Buy aprobado).
    @MainActor func startObservingTransactions()
}

enum ProductID {
    static let monthly = "com.matiasrodriguezc.lumbre.pro.monthly"
    static let annual = "com.matiasrodriguezc.lumbre.pro.annual"
    static let all = [monthly, annual]
}

// MARK: - StoreKit 2

final class StoreKitPurchaseService: PurchaseService {
    private let logger = Logger(subsystem: "com.matiasrodriguezc.lumbre", category: "purchases")
    private let updates = OSAllocatedUnfairLock<Task<Void, Never>?>(initialState: nil)

    func offers() async throws -> [PlanOffer] {
        let products = try await Product.products(for: ProductID.all)
        guard !products.isEmpty else { throw PurchaseError.productsUnavailable }
        var offers: [PlanOffer] = []
        for product in products {
            let period: PlanPeriod = product.id == ProductID.annual ? .annual : .monthly
            var trialDays: Int?
            if let subscription = product.subscription,
               let intro = subscription.introductoryOffer,
               intro.paymentMode == .freeTrial,
               await subscription.isEligibleForIntroOffer {
                trialDays = intro.period.days
            }
            offers.append(PlanOffer(
                id: product.id,
                period: period,
                displayPrice: product.displayPrice,
                price: product.price,
                currencyCode: product.priceFormatStyle.currencyCode,
                trialDays: trialDays
            ))
        }
        return offers.sorted { $0.period == .annual && $1.period != .annual }
    }

    func purchase(_ offer: PlanOffer) async throws -> PurchaseOutcome {
        guard let product = try await Product.products(for: [offer.id]).first else {
            throw PurchaseError.productsUnavailable
        }
        // TODO(paso 54): pasar `appAccountToken` con el id del usuario cuando RevenueCat esté configurado.
        switch try await product.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { throw PurchaseError.unverified }
            await transaction.finish()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restore() async throws -> Bool {
        try await AppStore.sync()
        return await hasActiveSubscription()
    }

    func hasActiveSubscription() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               ProductID.all.contains(transaction.productID),
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    @MainActor func startObservingTransactions() {
        let logger = logger
        updates.withLock { task in
            guard task == nil else { return }
            task = Task.detached {
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result {
                        await transaction.finish()
                    } else {
                        logger.notice("Transacción sin verificar")
                    }
                }
            }
        }
    }
}

private extension Product.SubscriptionPeriod {
    var days: Int {
        switch unit {
        case .day: value
        case .week: value * 7
        case .month: value * 30
        case .year: value * 365
        @unknown default: value
        }
    }
}

// MARK: - Simulada

/// Compras simuladas para previews y para `-mock` en Debug, con los precios de plan.md §8.
final class PreviewPurchaseService: PurchaseService {
    private let active = OSAllocatedUnfairLock(initialState: false)
    private let failsLoading: Bool

    init(failsLoading: Bool = false) {
        self.failsLoading = failsLoading
    }

    func offers() async throws -> [PlanOffer] {
        try await Task.sleep(for: .milliseconds(400))
        if failsLoading { throw PurchaseError.productsUnavailable }
        return [
            PlanOffer(id: ProductID.annual, period: .annual, displayPrice: Decimal(string: "49.99")!.formatted(.currency(code: "USD")),
                      price: Decimal(string: "49.99")!, currencyCode: "USD", trialDays: 7),
            PlanOffer(id: ProductID.monthly, period: .monthly, displayPrice: Decimal(string: "6.99")!.formatted(.currency(code: "USD")),
                      price: Decimal(string: "6.99")!, currencyCode: "USD", trialDays: nil),
        ]
    }

    func purchase(_ offer: PlanOffer) async throws -> PurchaseOutcome {
        try await Task.sleep(for: .milliseconds(800))
        active.withLock { $0 = true }
        return .purchased
    }

    func restore() async throws -> Bool {
        try await Task.sleep(for: .milliseconds(600))
        return active.withLock { $0 }
    }

    func hasActiveSubscription() async -> Bool {
        active.withLock { $0 }
    }

    @MainActor func startObservingTransactions() {}
}

extension EnvironmentValues {
    /// Compras de Pro. Lo inyecta `LumbreApp`; las previews usan las simuladas.
    @Entry var purchases: any PurchaseService = PreviewPurchaseService()
}

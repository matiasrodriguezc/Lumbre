import LumbreCore
import os
import SwiftUI
import UIKit
import UserNotifications

private let logger = Logger(subsystem: "com.matiasrodriguezc.lumbre", category: "push")

/// Delegado de la app: registra el token de APNs, abre la chispa al tocar una notificación
/// y escucha las transacciones de StoreKit. Es dueño del backend y del estado global para que
/// una notificación que abre la app en frío tenga a quién avisarle.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    let api: any LumbreAPI = LumbreApp.makeAPI()
    let appModel = AppModel()
    let purchases: any PurchaseService = LumbreApp.makePurchaseService()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        purchases.startObservingTransactions()
        Task {
            // Si ya dio permiso antes, el token puede haber cambiado: se vuelve a registrar en cada arranque.
            if await PushPermission.status() == .authorized {
                application.registerForRemoteNotifications()
            }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        #if DEBUG
        let sandbox = true
        #else
        let sandbox = false
        #endif
        let api = api
        Task {
            do {
                try await api.registerPushToken(token, sandbox: sandbox)
            } catch {
                logger.error("No se pudo registrar el token de push: \(String(describing: error), privacy: .public)")
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // En el simulador y sin la capability de push (falta la cuenta de Apple Developer) esto es esperable.
        logger.notice("APNs no disponible: \(error.localizedDescription, privacy: .public)")
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Con la app abierta, la chispa del día se muestra igual como banner.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        let userInfo = content.userInfo
        let type = (userInfo["type"] as? String) ?? "daily_spark"
        let minutes = Int(Date.now.timeIntervalSince(response.notification.date) / 60)
        Analytics.track(.notificationOpened(type: type, minutesAfterSent: max(0, minutes)))

        if let rawID = userInfo["spark_id"] as? String, let sparkID = UUID(uuidString: rawID) {
            appModel.open(.spark(sparkID, entry: "push"))
        } else {
            appModel.open(.today)
        }
    }
}

/// Permiso de notificaciones.
enum PushPermission {
    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Pide el permiso del sistema si todavía no se pidió. Devuelve si quedó aceptado y si se mostró el pedido del sistema.
    /// Si acepta, registra el dispositivo en APNs.
    @MainActor
    static func request() async -> (granted: Bool, systemPromptShown: Bool) {
        let before = await status()
        guard before == .notDetermined else {
            let granted = before == .authorized || before == .provisional
            if granted { UIApplication.shared.registerForRemoteNotifications() }
            return (granted, false)
        }
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted { UIApplication.shared.registerForRemoteNotifications() }
        return (granted, true)
    }
}

/// Notificación local de respaldo a la hora de la chispa, para que el loop funcione sin APNs
/// mientras no hay claves. Cuando el backend mande la push diaria (paso 32), esto se apaga
/// para no avisar dos veces.
enum SparkReminder {
    static let identifier = "daily-spark-local"

    /// Programa (o reprograma) el aviso diario. No hace nada si no hay permiso.
    static func schedule(at time: SparkTime) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Tu chispa de hoy está lista")
        content.body = String(localized: "Dos neuronas de tu red se conectaron. Entrá a ver qué chispa salió.")
        content.sound = .default
        content.userInfo = ["type": "daily_spark"]

        var components = DateComponents()
        components.hour = time.hour
        components.minute = time.minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        do {
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        } catch {
            logger.error("No se pudo programar el aviso local: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

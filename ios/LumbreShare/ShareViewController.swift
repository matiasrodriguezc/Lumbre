import LumbreCore
import LumbreDesign
import SwiftUI
import UIKit

/// Punto de entrada de la Share Extension (paso 49): aloja `ShareView` y cierra el pedido del sistema.
/// Sin claves de IA ni login propio: manda con la sesión que dejó la app o encola para que la mande la app.
@objc(ShareViewController)
final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        let root = ShareView(
            model: model,
            onCancel: { [weak self] in self?.cancel() },
            onDone: { [weak self] in self?.finish() }
        )
        .preferredColorScheme((LumbreShared.theme.flatMap(ThemePreference.init(rawValue:)) ?? .light).colorScheme)

        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)

        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        Task { await model.load(items) }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: CocoaError(.userCancelled))
    }
}

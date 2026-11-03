import SwiftUI
import UIKit

/// Resolves presentation within the originating SwiftUI hierarchy, never another scene.
struct ScenePresentationAnchor: UIViewControllerRepresentable {
    var resolve: (UIViewController) -> Void
    init(_ resolve: @escaping (UIViewController) -> Void) { self.resolve = resolve }
    final class Controller: UIViewController {
        var resolve: ((UIViewController) -> Void)?
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            resolve?(parent ?? self)
        }
    }
    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller(); controller.resolve = resolve
        controller.view.backgroundColor = .clear
        return controller
    }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.resolve = resolve
        if controller.viewIfLoaded?.window != nil {
            DispatchQueue.main.async { resolve(controller.parent ?? controller) }
        }
    }
    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) { controller.resolve = nil }
    static func presenter(for view: UIView, followingPresented: Bool = true) -> UIViewController? {
        var responder: UIResponder? = view
        while let current = responder {
            if let controller = current as? UIViewController { return followingPresented ? top(from: controller) : controller }
            responder = current.next
        }
        return nil
    }
    static func top(from controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController, !presented.isBeingDismissed { return top(from: presented) }
        if let navigation = controller as? UINavigationController, let visible = navigation.visibleViewController { return top(from: visible) }
        if let tab = controller as? UITabBarController, let selected = tab.selectedViewController { return top(from: selected) }
        return controller
    }
}

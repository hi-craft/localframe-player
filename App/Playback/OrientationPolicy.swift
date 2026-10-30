import UIKit

/// Keep the phone library portrait, and allow rotation while the player is open.
/// The application mask survives dismissal of SwiftUI's presentation controller.
@MainActor final class OrientationPolicy {
    static let shared = OrientationPolicy()
    private(set) var phoneMask: UIInterfaceOrientationMask = .portrait
    private var rotationRequest = UUID()
    private var waitingForUprightDevice = false
    private var orientationObserver: NSObjectProtocol?

    private init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.waitingForUprightDevice, UIDevice.current.orientation == .portrait else { return }
                self.waitingForUprightDevice = false
                self.update(.allButUpsideDown)
            }
        }
    }

    func enterPlayer() { waitingForUprightDevice = false; update(.allButUpsideDown) }
    func showLibrary() { waitingForUprightDevice = false; update(.portrait, rotateTo: .portrait) }
    func fullscreen(_ enabled: Bool) {
        waitingForUprightDevice = !enabled
        update(enabled ? .landscape : .portrait,
               rotateTo: enabled ? .landscapeRight : .portrait)
    }

    private func update(_ mask: UIInterfaceOrientationMask, rotateTo: UIInterfaceOrientationMask? = nil) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        phoneMask = mask
        let request = UUID()
        rotationRequest = request
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            where scene.activationState == .foregroundActive {
            var controller = scene.windows.first(where: \.isKeyWindow)?.rootViewController
            while let current = controller {
                current.setNeedsUpdateOfSupportedInterfaceOrientations()
                controller = current.presentedViewController
            }
            let current = UIInterfaceOrientationMask(rawValue: 1 << scene.interfaceOrientation.rawValue)
            // Library onAppear/onDismiss can both reapply the portrait policy.
            // Do not start a second geometry transition for an already upright window.
            if let rotateTo, !rotateTo.contains(current) {
                DispatchQueue.main.async { [weak self, weak scene] in
                    guard self?.rotationRequest == request, let scene else { return }
                    scene.requestGeometryUpdate(.iOS(interfaceOrientations: rotateTo)) { error in
                        NSLog("Vela orientation request failed: %@", error.localizedDescription)
                    }
                }
            }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .phone ? OrientationPolicy.shared.phoneMask : .all
    }
}

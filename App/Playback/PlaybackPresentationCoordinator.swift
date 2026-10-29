import SwiftUI
import UIKit

/// Dismiss only after the phone has finished returning to portrait. A cover
/// dismissal during UIKit's rotation creates competing window transitions.
struct PlaybackPresentationCoordinator: UIViewControllerRepresentable {
    let closeRequested: Bool
    let close: () -> Void

    func makeUIViewController(context: Context) -> PlaybackPresentationController {
        PlaybackPresentationController()
    }

    func updateUIViewController(_ controller: PlaybackPresentationController, context: Context) {
        controller.closeRequested = closeRequested
        controller.close = close
        controller.finishClosingIfReady()
    }
}

final class PlaybackPresentationController: UIViewController {
    var closeRequested = false
    var close: (() -> Void)?
    private var rotating = false

    override func loadView() {
        view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        finishClosingIfReady()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        rotating = true
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.rotating = false
            self?.finishClosingIfReady()
        }
    }

    func finishClosingIfReady() {
        // SwiftUI may update this controller while evaluating its view tree.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.closeRequested, !self.rotating,
                  let scene = self.view.window?.windowScene else { return }
            guard UIDevice.current.userInterfaceIdiom != .phone || scene.interfaceOrientation.isPortrait else { return }
            self.closeRequested = false
            self.close?()
        }
    }
}

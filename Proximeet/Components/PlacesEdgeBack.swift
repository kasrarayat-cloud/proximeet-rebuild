import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Places' back gesture (chapter 07 correction). While a Places screen is in a window, a swipe in
/// from the leading edge goes back exactly one stage, as that screen's Back controls do: a detail
/// to its category, the explanation to Common Ground's detail, browsing to the actual Signal.
///
/// Places shows its three stages inside one navigation destination, so a ticket can expand into
/// its detail; left alone, the navigation stack's own back gestures would take any stage straight
/// to Signal. So, only while Places is on screen: the stack's pans and scroll views wait for this
/// edge pan to fail, and while a detail or the explanation shows, the stack's swipe-from-anywhere
/// pop (iOS 26) is held off. Nothing changes outside Places. The SwiftUI side decides what a
/// finished swipe does; a swipe that is not completed changes nothing.
struct PlacesEdgeBack: UIViewRepresentable {
    /// A detail or the explanation is showing: the content pop is held off.
    var innerStage: Bool
    /// The finger's horizontal travel from the edge, while the swipe is in progress.
    var changed: (CGFloat) -> Void
    /// The swipe ended: its travel, its horizontal velocity and the width it travelled across.
    var ended: (_ translation: CGFloat, _ velocity: CGFloat, _ width: CGFloat) -> Void
    /// The system cancelled the swipe.
    var cancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> Anchor {
        let anchor = Anchor()
        anchor.coordinator = context.coordinator
        return anchor
    }

    func updateUIView(_ anchor: Anchor, context: Context) {
        let coordinator = context.coordinator
        coordinator.changed = changed
        coordinator.ended = ended
        coordinator.cancelled = cancelled
        coordinator.innerStage = innerStage
        coordinator.holdContentPop(from: anchor)
    }

    static func dismantleUIView(_ anchor: Anchor, coordinator: Coordinator) {
        coordinator.innerStage = false
        coordinator.holdContentPop(from: anchor)
        coordinator.recognizer.view?.removeGestureRecognizer(coordinator.recognizer)
    }

    @MainActor
    final class Coordinator: NSObject {
        let recognizer = PlacesEdgePanRecognizer()
        var changed: (CGFloat) -> Void = { _ in }
        var ended: (CGFloat, CGFloat, CGFloat) -> Void = { _, _, _ in }
        var cancelled: () -> Void = {}
        var innerStage = false
        private weak var navigation: UINavigationController?

        override init() {
            super.init()
            recognizer.edges = .left
            recognizer.addTarget(self, action: #selector(pan(_:)))
        }

        @objc private func pan(_ recognizer: UIScreenEdgePanGestureRecognizer) {
            guard let space = recognizer.view else { return }
            let translation = max(0, recognizer.translation(in: space).x)
            switch recognizer.state {
            case .began, .changed:
                changed(translation)
            case .ended:
                ended(translation, recognizer.velocity(in: space).x, space.bounds.width)
            case .cancelled, .failed:
                cancelled()
            default:
                break
            }
        }

        /// Holds the stack's swipe-from-anywhere pop (`interactiveContentPopGestureRecognizer`,
        /// iOS 26) off while a detail or the explanation shows, and gives it back otherwise. Looked
        /// up by name, so systems without it are unaffected.
        func holdContentPop(from anchor: UIView) {
            if anchor.window != nil, let found = Self.navigationController(of: anchor) {
                navigation = found
            }
            guard let navigation else { return }
            let key = "interactiveContentPopGestureRecognizer"
            guard navigation.responds(to: NSSelectorFromString(key)),
                  let contentPop = navigation.value(forKey: key) as? UIGestureRecognizer
            else { return }
            contentPop.isEnabled = !innerStage
        }

        private static func navigationController(of view: UIView) -> UINavigationController? {
            var responder: UIResponder? = view
            while let current = responder {
                if let controller = current as? UIViewController, let navigation = controller.navigationController {
                    return navigation
                }
                responder = current.next
            }
            return nil
        }
    }

    /// Adds the edge pan to its window while it is in one. Takes no touches and is not an
    /// accessibility element.
    final class Anchor: UIView {
        weak var coordinator: Coordinator?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isAccessibilityElement = false
            accessibilityElementsHidden = true
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let coordinator else { return }
            coordinator.recognizer.view?.removeGestureRecognizer(coordinator.recognizer)
            if let window {
                window.addGestureRecognizer(coordinator.recognizer)
            } else {
                // Leaving the screen: the content pop belongs to the whole stack again.
                coordinator.innerStage = false
            }
            coordinator.holdContentPop(from: self)
        }
    }
}

/// An edge pan that the navigation stack's own pans and scroll views wait for, so a swipe from the
/// leading edge is Places' one-stage Back: never a pop straight to Signal, never a scroll. It fails
/// at once for a touch that does not start at the edge, so nothing else is delayed.
final class PlacesEdgePanRecognizer: UIScreenEdgePanGestureRecognizer {
    override func shouldBeRequiredToFail(by other: UIGestureRecognizer) -> Bool {
        guard !(other is PlacesEdgePanRecognizer), other is UIPanGestureRecognizer else { return false }
        if other is UIScreenEdgePanGestureRecognizer || other.view is UIScrollView {
            return true
        }
        return other.view?.next is UINavigationController
    }
}

import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// While its view is in a window, swallows the repeated taps of a rapid multi-tap anywhere in
/// that window: touches whose `UITouch.tapCount` is above 1. UIKit counts a tap as a repeat
/// only when it lands close to the previous one within the system's multi-tap interval, so a
/// quick double tap on "Try the demo" cannot also press "Finish preview" underneath it, a
/// double tap on Back cannot also press Birthday's Back while Pass slides away, and a double
/// tap on "Edit introduction" cannot also press the editor's Back in the same place.
///
/// A first tap is never delayed or altered: the recognizer fails as soon as it sees one, and it
/// has no timer of its own. Text fields keep their own double and triple taps (selecting a word
/// or a paragraph). VoiceOver activation sends no touches and is unaffected.
struct RepeatTapGuard: UIViewRepresentable {
    func makeUIView(context: Context) -> GuardView {
        GuardView()
    }

    func updateUIView(_ view: GuardView, context: Context) {}

    final class GuardView: UIView {
        private let swallower = RepeatTapSwallower(target: nil, action: nil)

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
            swallower.view?.removeGestureRecognizer(swallower)
            window?.addGestureRecognizer(swallower)
        }
    }
}

/// Recognizes (and so cancels, for every view under it) only a touch that UIKit reports as
/// the second or later tap of a multi-tap; fails immediately for any other touch.
final class RepeatTapSwallower: UIGestureRecognizer {
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = true
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard state == .possible else { return }
        let repeated = touches.contains { $0.tapCount > 1 && !Self.isInTextField($0.view) }
        state = repeated ? .began : .failed
    }

    /// Every other recognizer under the window (SwiftUI's buttons included) waits for this one,
    /// which decides at once, when the touch begins: a first tap is not delayed, and a repeat is
    /// not also delivered to what is underneath. Another guard's swallower (Pass and Guest List
    /// share the window during a push or pop) is not made to wait, so the two never wait on each
    /// other.
    override func shouldBeRequiredToFail(by otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        !(otherGestureRecognizer is RepeatTapSwallower)
    }

    /// Whether `view` is a text field or text view, or lies inside one.
    private static func isInTextField(_ view: UIView?) -> Bool {
        var current = view
        while let candidate = current {
            if candidate is UITextField || candidate is UITextView { return true }
            current = candidate.superview
        }
        return false
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .began || state == .changed {
            state = .ended
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .began || state == .changed {
            state = .cancelled
        }
    }
}

import Foundation

/// Chapter 03, the approved Pass: a preview of an age-check experience that the guest steps
/// through by hand. It checks nothing, proves nothing and records nothing.
///
/// Three presentation stages, each changed only by the matching explicit action:
///
///     intro    --start-->  progress  --finish-->  complete
///     intro   <--cancel--  progress
///
/// Every action names the stage it belongs to and does nothing from any other stage, so a
/// repeated or stale action (a second "Try the demo" arriving after the first) can never
/// skip a stage. There is no time input, no persistence and no link to the rest of the
/// draft. A new value, and so every re-entry to Pass, starts at `intro`.
public struct PassDemo: Equatable, Sendable {
    public enum Stage: Equatable, Sendable, CaseIterable {
        /// "Your next chapter." Try the demo, or leave.
        case intro
        /// "Demo in progress." Finish preview, or cancel back to the intro.
        case progress
        /// "Demo complete." Continue preview opens the approved Guest List.
        case complete
    }

    public private(set) var stage: Stage = .intro

    public init() {}

    /// "Try the demo": intro → progress. Ignored in any other stage.
    @discardableResult
    public mutating func start() -> Bool {
        guard stage == .intro else { return false }
        stage = .progress
        return true
    }

    /// "Finish preview": progress → complete. Available as soon as progress is shown.
    /// Ignored in any other stage.
    @discardableResult
    public mutating func finish() -> Bool {
        guard stage == .progress else { return false }
        stage = .complete
        return true
    }

    /// "Cancel": progress → intro, staying on Pass. Ignored in any other stage.
    @discardableResult
    public mutating func cancel() -> Bool {
        guard stage == .progress else { return false }
        stage = .intro
        return true
    }

    /// "Continue preview" on complete. Returns whether the guest may move on to the approved
    /// Guest List (`DemoFlow.continueFromCompletedPass`); the stage never changes, so returning
    /// to the Pass finds it complete.
    public func continuePreview() -> Bool {
        stage == .complete
    }
}

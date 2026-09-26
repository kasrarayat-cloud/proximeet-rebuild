/// Chapter 04, the approved Guest List: its two presentation stages, each changed only by the
/// guest's own action.
///
///     editor  --preview (a previewable draft)-->  card
///     editor  <--edit------------------------------  card
///
/// Like `PassDemo`, every action names the stage it belongs to and does nothing from any other
/// stage, so a repeated or stale tap cannot skip one. The introduction itself lives in the
/// draft (`DemoDraft.introduction`); a new value, and so every entry to Guest List, starts at the
/// editor with that draft.
public struct GuestListDemo: Equatable, Sendable {
    public enum Stage: Equatable, Sendable, CaseIterable {
        /// "A little about you." The name, the opener and the interests.
        case editor
        /// "Your first hello." The personal card.
        case card
    }

    public private(set) var stage: Stage = .editor

    public init() {}

    /// "Preview my card": editor → card, only for a previewable draft. Ignored on the card.
    @discardableResult
    public mutating func preview(_ introduction: GuestIntroduction) -> Bool {
        guard stage == .editor, introduction.canPreview else { return false }
        stage = .card
        return true
    }

    /// "Edit introduction" or Back on the card: card → editor. Ignored in the editor.
    @discardableResult
    public mutating func edit() -> Bool {
        guard stage == .card else { return false }
        stage = .editor
        return true
    }

    /// "Continue preview" on the card. Returns whether the card may move on: the stage never
    /// changes, and `DemoFlow.continueFromGuestListCard` then opens the approved Wristband.
    public func continuePreview() -> Bool {
        stage == .card
    }
}

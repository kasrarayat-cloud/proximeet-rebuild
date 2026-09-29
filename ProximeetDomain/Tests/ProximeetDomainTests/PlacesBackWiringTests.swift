import Foundation
import XCTest

/// The app's Places screen, read as source (no UI framework on Linux): every Back it offers goes
/// through one `back(from:)`, which alone asks the domain's shared `placesBack(from:)`, and
/// VoiceOver's escape is one of them, owned by the screen's container. XCUITest cannot perform the
/// escape gesture, so this is where its wiring is pinned. Comments are ignored.
final class PlacesBackWiringTests: XCTestCase {
    private func placesViewCode() throws -> String {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // ProximeetDomainTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // ProximeetDomain
            .deletingLastPathComponent()   // repository root
            .appendingPathComponent("Proximeet/Scenes/PlacesView.swift")
        return try String(contentsOf: source, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> Substring in
                guard let comment = line.range(of: "//") else { return line }
                return line[..<comment.lowerBound]
            }
            .joined(separator: "\n")
    }

    private func matches(_ pattern: String, in code: String) throws -> Int {
        let regex = try NSRegularExpression(pattern: pattern)
        return regex.numberOfMatches(in: code, range: NSRange(code.startIndex..., in: code))
    }

    /// The body of the first function whose declaration starts with `declaration`, braces matched.
    private func body(of declaration: String, in code: String) throws -> Substring {
        let start = try XCTUnwrap(code.range(of: declaration), "\(declaration) not found")
        let open = try XCTUnwrap(code[start.upperBound...].firstIndex(of: "{"))
        var depth = 0
        var index = open
        while index < code.endIndex {
            switch code[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return code[open...index] }
            default: break
            }
            index = code.index(after: index)
        }
        XCTFail("\(declaration) has no closing brace")
        return ""
    }

    func testEscapeIsHandledOnTheScreensContainerThroughTheSharedBack() throws {
        let code = try placesViewCode()
        XCTAssertEqual(try matches(#"\.accessibilityElement\(children: \.contain\)\s*\.accessibilityAction\(\.escape\)\s*\{\s*escape\(from: stage\)\s*\}"#,
                                   in: code), 1, "one escape action, on a container, calling escape(from: stage)")
        XCTAssertEqual(try matches(#"\.toolbar\(\.hidden, for: \.navigationBar\)\s*\.accessibilityElement\(children: \.contain\)\s*\.accessibilityAction\(\.escape\)\s*\{\s*escape\(from: stage\)\s*\}\s*\.accessibilityIdentifier\("places\.screen"\)"#,
                                   in: code), 1, "the container is the whole screen's, identified places.screen")
        XCTAssertEqual(try matches(#"\.accessibilityAction\(\.escape\)"#, in: code), 1, "no second escape owner")
        XCTAssertEqual(try matches(#""places\.screen""#, in: code), 1, "one places.screen")
        // Chapter 8: while the Room is shown above the explanation, escape is the Room's outer Back
        // (it closes the Room's top level, or leaves); otherwise it is unchanged.
        XCTAssertEqual(try matches(#"private func escape\(from stage: PlacesStage\) \{\s*if session\.room != nil \{\s*RoomView\.outerBack\(session, animation: dissolveAnimation\)\s*return\s*\}\s*guard !backCompleting else \{ return \}\s*backDrag = 0\s*back\(from: stage\)\s*\}"#,
                                   in: code), 1, "escape is the Room's outer Back while it is shown, else the controls' own one-stage Back, ignored while a swipe completes")
    }

    func testNoControlGoesBackAroundTheSharedRoute() throws {
        let code = try placesViewCode()
        for own in ["leavePlaces(", "leavePlaceDetail(", "backToPlace(", "goBack(", "returnTo(", "adoptNavigationPath(",
                    "navigationPath"] {
            XCTAssertFalse(code.contains(own), "PlacesView calls \(own) directly; use back(from:)")
        }
        let back = try body(of: "private func back(from stage: PlacesStage", in: code)
        let inBack = try matches(#"session\.placesBack\(from: stage\.scene\)"#, in: String(back))
        XCTAssertGreaterThanOrEqual(inBack, 1, "back(from:) asks the shared route")
        XCTAssertEqual(try matches(#"placesBack\("#, in: code), inBack, "only back(from:) asks the shared route")
        XCTAssertEqual(try matches(#"case \.browse: return \.places\s*case \.detail: return \.placeDetail\s*case \.explanation: return \.placeExplanation"#,
                                   in: code), 1, "each stage asks from its own scene")
    }

    func testEveryBackControlUsesTheSharedBack() throws {
        let code = try placesViewCode()
        let controls: [(String, String)] = [
            (#"Button \{\s*back\(from: stage\)\s*\} label:"#, "the header's Back"),
            (#"Button\("Back"\) \{\s*back\(from: \.browse\)\s*\}"#, "browsing's bottom Back"),
            (#"Button\("Back to places"\) \{\s*back\(from: \.detail\)\s*\}"#, "Back to places"),
            (#"Button\("Back to place"\) \{\s*back\(from: \.explanation\)\s*\}"#, "Back to place"),
            (#"if !back\(from: \.browse\) \{\s*swipeCancelled\(\)"#, "a completed swipe from browsing"),
            (#"backDrag = 0\s*back\(from: stage\)\s*return"#, "a completed swipe under Reduce Motion or VoiceOver"),
            (#"back\(from: stage, afterSwipe: true\)"#, "a completed swipe's instant stage change"),
        ]
        for (pattern, control) in controls {
            XCTAssertEqual(try matches(pattern, in: code), 1, control)
        }
    }
}

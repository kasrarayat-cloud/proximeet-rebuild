import Foundation
import XCTest
import ProximeetDomain

/// The approved Guest List's introduction rules (chapter 04). Every name and opener here is
/// fictional test data.
final class GuestIntroductionTests: XCTestCase {
    private typealias Interest = GuestIntroduction.Interest

    // MARK: - Empty start

    func testStartsEmpty() {
        let introduction = GuestIntroduction()
        XCTAssertEqual(introduction.name, "")
        XCTAssertEqual(introduction.opener, "")
        XCTAssertEqual(introduction.interests, [])
        XCTAssertEqual(introduction.openerCount, 0)
        XCTAssertTrue(introduction.isNameBlank)
        XCTAssertFalse(introduction.canPreview, "Preview needs a name")
        XCTAssertNil(introduction.card)
        XCTAssertEqual(DemoDraft().introduction, introduction, "A new draft starts empty, never prefilled")
    }

    // MARK: - Name

    func testOnlyWhitespaceOrNewlineNamesAreBlank() {
        for blank in ["", " ", "   ", "\n", "\r\n", "\t \n ", "\u{00A0}", "\u{3000}", "\u{2028}", " \u{0301}"] {
            let introduction = GuestIntroduction(name: blank)
            XCTAssertTrue(introduction.isNameBlank, "\(blank.debugDescription) is blank")
            XCTAssertFalse(introduction.canPreview)
            XCTAssertNil(introduction.card)
        }
    }

    func testAnyOtherNameIsAcceptedExactlyAsEntered() {
        let names = [
            "A", "Zoë", "José María", "Siobhán O'Brien-Nakamura", "李明华", "김민지", "محمد", "Nguyễn Văn An",
            "Ólafur", "Wanjirũ wa Kamau", "e\u{0301}lodie", "🦊", "x.y_z", "J.", "Anne-Marie", "Ivan 3rd",
            String(repeating: "Maximiliana ", count: 20),
        ]
        for name in names {
            var introduction = GuestIntroduction()
            introduction.name = name
            XCTAssertFalse(introduction.isNameBlank, "\(name) is a name")
            XCTAssertTrue(introduction.canPreview, "No surname, length, script or character rule: \(name)")
            XCTAssertEqual(introduction.name, name, "The raw draft is never rewritten")
        }
    }

    func testTheCardTrimsOnlyTheEdgesAndKeepsTheDraftRaw() throws {
        let raw = "  \n José  María\u{00A0} \n"
        let introduction = GuestIntroduction(name: raw)
        let card = try XCTUnwrap(introduction.card)
        XCTAssertEqual(card.name, "José  María", "Inner spacing and accents are kept")
        XCTAssertEqual(introduction.name, raw, "The draft keeps the edges")
    }

    func testInitialIsTheFirstGraphemeOfTheFirstNonblankToken() throws {
        let cases: [(String, String)] = [
            ("Alex", "A"),
            ("  김민지 Park", "김"),
            ("\n\tmohammed", "m"),
            ("محمد سالم", "م"),
            ("李明华", "李"),
            ("e\u{0301}lodie", "e\u{0301}"),
            ("\u{1100}\u{1161}\u{11A8}\u{1100}", "\u{1100}\u{1161}\u{11A8}"),
            ("👩🏽‍💻 Dev", "👩🏽‍💻"),
            ("🇮🇸 Ísland", "🇮🇸"),
            ("ßophie", "ß"),
            ("Ǆemal", "Ǆ"),
        ]
        for (name, initial) in cases {
            let card = try XCTUnwrap(GuestIntroduction(name: name).card, name)
            XCTAssertEqual(card.initial, initial, "The initial of \(name.debugDescription)")
            XCTAssertEqual(card.initial.count, 1, "One grapheme, never split: \(name.debugDescription)")
        }
    }

    // MARK: - Opener

    func testOpenerCountsUserPerceivedCharacters() {
        let family = "👩‍👩‍👧‍👦"
        let flag = "🇺🇳"
        let composed = "e\u{0301}"
        let hangul = "\u{1100}\u{1161}\u{11A8}"
        XCTAssertEqual(GuestIntroduction(opener: family).openerCount, 1)
        XCTAssertEqual(GuestIntroduction(opener: flag).openerCount, 1)
        XCTAssertEqual(GuestIntroduction(opener: composed).openerCount, 1)
        XCTAssertEqual(GuestIntroduction(opener: hangul).openerCount, 1)
        XCTAssertEqual(GuestIntroduction(opener: "\r\n").openerCount, 1)
        XCTAssertEqual(GuestIntroduction(opener: "Always up for coffee and a good story.").openerCount, 38,
                       "The approved fictional sample is 38 characters")
    }

    func testThe120And121Boundaries() {
        let units = ["a", "👩‍👩‍👧‍👦", "🇺🇳", "e\u{0301}", "\u{1100}\u{1161}\u{11A8}", "👍🏾", "漢"]
        for unit in units {
            let limit = String(repeating: unit, count: 120)
            var introduction = GuestIntroduction(name: "Alex", opener: limit)
            XCTAssertEqual(introduction.openerCount, 120, unit)
            XCTAssertTrue(introduction.isOpenerWithinLimit, "120 × \(unit) is within the limit")
            XCTAssertTrue(introduction.canPreview)

            introduction.opener += unit
            XCTAssertEqual(introduction.openerCount, 121, unit)
            XCTAssertFalse(introduction.isOpenerWithinLimit, "121 × \(unit) is over the limit")
            XCTAssertFalse(introduction.canPreview, "Over the limit holds back the preview")
            XCTAssertNil(introduction.card)
        }
        // Scalars and UTF-16 units are not the measure: 120 families are 2,520 UTF-16 units.
        let families = String(repeating: "👩‍👩‍👧‍👦", count: 120)
        XCTAssertGreaterThan(families.utf16.count, 120)
        XCTAssertTrue(GuestIntroduction(name: "Alex", opener: families).canPreview)
    }

    func testAnOverLimitPasteStaysWholeAndCanBeCorrected() throws {
        let pasted = String(repeating: "Coffee? 👩🏽‍💻 e\u{0301} ", count: 15) + "fin"
        XCTAssertGreaterThan(pasted.count, 120)
        var flow = GuestListRoute.onGuestList()
        XCTAssertTrue(flow.editIntroduction { $0.name = "Alex" })
        XCTAssertTrue(flow.editIntroduction { $0.opener = pasted })
        XCTAssertEqual(flow.draft.introduction.opener, pasted, "Nothing is truncated or sliced")
        XCTAssertEqual(flow.draft.introduction.opener.unicodeScalars.count, pasted.unicodeScalars.count)
        XCTAssertFalse(flow.draft.introduction.canPreview)

        // The guest corrects it; exactly 120 characters is allowed again.
        XCTAssertTrue(flow.editIntroduction { $0.opener = String($0.opener.prefix(120)) })
        XCTAssertEqual(flow.draft.introduction.openerCount, 120)
        XCTAssertTrue(flow.draft.introduction.canPreview)
    }

    func testWhitespaceOnlyOpenerIsOmittedAndOtherOpenersAreTrimmedOnlyAtTheEdges() throws {
        for blank in ["", " ", "\n\n", " \t "] {
            let card = try XCTUnwrap(GuestIntroduction(name: "Alex", opener: blank).card)
            XCTAssertNil(card.opener, "\(blank.debugDescription) shows no opener")
        }
        let raw = "\n  Hi there,\nnice to meet you.  "
        let introduction = GuestIntroduction(name: "Alex", opener: raw)
        XCTAssertEqual(try XCTUnwrap(introduction.card).opener, "Hi there,\nnice to meet you.")
        XCTAssertEqual(introduction.opener, raw, "The draft keeps the opener as entered")
    }

    // MARK: - Interests

    func testTheCatalogIsExactlyThreeInOrder() {
        XCTAssertEqual(Interest.allCases.map(\.label), ["Coffee", "Live music", "Outdoors"])
    }

    func testInterestsToggleIndependentlyAndStayInCatalogOrder() {
        var introduction = GuestIntroduction(name: "Alex")
        introduction.toggle(.outdoors)
        introduction.toggle(.coffee)
        XCTAssertEqual(introduction.interests, [.coffee, .outdoors], "Catalog order, not tap order")
        XCTAssertTrue(introduction.isSelected(.coffee))
        XCTAssertFalse(introduction.isSelected(.liveMusic))

        introduction.toggle(.coffee)
        XCTAssertEqual(introduction.interests, [.outdoors], "Deselecting one leaves the others")
        introduction.toggle(.liveMusic)
        introduction.toggle(.coffee)
        XCTAssertEqual(introduction.interests, [.coffee, .liveMusic, .outdoors])
        introduction.toggle(.liveMusic)
        XCTAssertEqual(introduction.interests, [.coffee, .outdoors])

        XCTAssertEqual(GuestIntroduction(interests: [.outdoors, .coffee, .outdoors]).interests, [.coffee, .outdoors])
    }

    func testEveryZeroToThreeSelectionIsValid() throws {
        for mask in 0..<8 {
            let chosen = Interest.allCases.enumerated().filter { mask & (1 << $0.offset) != 0 }.map(\.element)
            let introduction = GuestIntroduction(name: "Alex", interests: chosen)
            XCTAssertTrue(introduction.canPreview, "\(chosen.count) interests are valid")
            XCTAssertEqual(try XCTUnwrap(introduction.card).interests, chosen)
        }
    }

    // MARK: - Card

    func testNameOnlyCardHasNoOptionalContent() throws {
        let card = try XCTUnwrap(GuestIntroduction(name: "Alex").card)
        XCTAssertEqual(card.name, "Alex")
        XCTAssertEqual(card.initial, "A")
        XCTAssertNil(card.opener, "no opener line")
        XCTAssertEqual(card.interests, [], "no interest line, so no separators")
    }

    func testTheFictionalAlexExampleCard() throws {
        let introduction = GuestIntroduction(
            name: "Alex", opener: "Always up for coffee and a good story.", interests: Interest.allCases
        )
        let card = try XCTUnwrap(introduction.card)
        XCTAssertEqual(card.name, "Alex")
        XCTAssertEqual(card.initial, "A")
        XCTAssertEqual(card.opener, "Always up for coffee and a good story.")
        XCTAssertEqual(card.interests.map(\.label), ["Coffee", "Live music", "Outdoors"])
    }

    func testNotPersistable() {
        for type in [GuestIntroduction.self, IntroductionCard.self, GuestListDemo.self] as [Any.Type] {
            XCTAssertFalse(type is Encodable.Type, "\(type)")
            XCTAssertFalse(type is Decodable.Type, "\(type)")
        }
    }
}

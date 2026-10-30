import Foundation
import XCTest
import ProximeetDomain

/// Places' one-stage Back (`DemoFlow.placesBack(from:)`): the single route behind the header's
/// Back, the bottom Back actions, the leading-edge swipe and VoiceOver's escape. Every venue, host,
/// name and opener here is fictional test data.
final class PlacesBackTests: XCTestCase {

    // MARK: - One stage, from every Places stage

    func testBrowsingGoesBackToTheActualSignalWithEverythingKept() {
        for intent in BandIntent.allCases {
            for category in PlaceCategory.allCases {
                var flow = PlacesRoute.onPlaces(intent, approach: .okayToSayHello)
                flow.choosePlaceCategory(category)
                let draft = flow.draft
                XCTAssertTrue(flow.placesBack(from: .places), "\(intent) / \(category)")
                XCTAssertEqual(flow.currentScene, .signal)
                XCTAssertEqual(flow.draft, draft, "the intent, the approach and the introduction are kept")
                XCTAssertEqual(flow.placesCategory, category, "the category is kept")
                XCTAssertTrue(flow.openPlaces())
                XCTAssertEqual(flow.placesCategory, category, "Continue preview reopens the category left")
            }
        }
    }

    func testADetailGoesBackToItsOriginatingCategory() {
        for intent in BandIntent.allCases {
            for category in PlaceCategory.allCases {
                var flow = PlacesRoute.onPlaces(intent, approach: .chatFirst)
                flow.choosePlaceCategory(category)
                XCTAssertTrue(flow.openPlaceDetail())
                let draft = flow.draft
                XCTAssertTrue(flow.placesBack(from: .placeDetail), "\(intent) / \(category)")
                XCTAssertEqual(flow.currentScene, .places, "a detail goes back to browsing, never to Signal")
                XCTAssertEqual(flow.placesCategory, category, "the originating category, never reset to Now")
                XCTAssertEqual(flow.draft, draft)
            }
        }
    }

    func testTheExplanationGoesBackToCommonGroundsDetail() {
        for intent in [BandIntent.social, .business] {
            var flow = PlacesRoute.onExplanation(intent)
            XCTAssertEqual(flow.currentScene, .placeExplanation, "\(intent)")
            let draft = flow.draft
            XCTAssertTrue(flow.placesBack(from: .placeExplanation), "\(intent)")
            XCTAssertEqual(flow.currentScene, .placeDetail, "the explanation goes back to the detail, not browsing")
            XCTAssertEqual(flow.placeVenue, .commonGround)
            XCTAssertEqual(flow.placesCategory, .now)
            XCTAssertEqual(flow.draft, draft)
        }
    }

    func testRepeatedRequestsFromTheExplanationWalkOneStageEach() {
        var flow = PlacesRoute.onExplanation(.social)
        XCTAssertTrue(flow.placesBack(from: flow.currentScene))
        XCTAssertEqual(flow.currentScene, .placeDetail)
        XCTAssertTrue(flow.placesBack(from: flow.currentScene))
        XCTAssertEqual(flow.currentScene, .places)
        XCTAssertTrue(flow.placesBack(from: flow.currentScene))
        XCTAssertEqual(flow.currentScene, .signal)
        XCTAssertFalse(flow.placesBack(from: flow.currentScene), "Places' Back never leaves Signal")
        XCTAssertEqual(flow.currentScene, .signal)
    }

    // MARK: - The same route as each stage's own action

    /// Every Places stage the approved journey can show, for every intent and category: the shared
    /// route lands exactly where that stage's own Back action does, with an identical flow.
    func testTheSharedRouteMatchesEachStagesOwnBack() {
        var explanations = 0
        for intent in BandIntent.allCases {
            for category in PlaceCategory.allCases {
                var browse = PlacesRoute.onPlaces(intent, approach: .chatFirst)
                browse.choosePlaceCategory(category)
                var viaOwn = browse
                var viaShared = browse
                XCTAssertTrue(viaOwn.leavePlaces())
                XCTAssertTrue(viaShared.placesBack(from: .places))
                XCTAssertEqual(viaShared, viaOwn, "browsing, \(intent) / \(category)")

                var detail = browse
                XCTAssertTrue(detail.openPlaceDetail())
                viaOwn = detail
                viaShared = detail
                XCTAssertTrue(viaOwn.leavePlaceDetail())
                XCTAssertTrue(viaShared.placesBack(from: .placeDetail))
                XCTAssertEqual(viaShared, viaOwn, "detail, \(intent) / \(category)")

                var explanation = detail
                guard explanation.previewCheckIn() else { continue }
                explanations += 1
                viaOwn = explanation
                viaShared = explanation
                XCTAssertTrue(viaOwn.backToPlace())
                XCTAssertTrue(viaShared.placesBack(from: .placeExplanation))
                XCTAssertEqual(viaShared, viaOwn, "explanation, \(intent) / \(category)")
            }
        }
        XCTAssertEqual(explanations, 4, "All four intents at Common Ground")
    }

    // MARK: - Stale requests and scenes outside Places

    /// A request made on a stage that is no longer current does nothing: a double tap on the
    /// header's Back, or a swipe that finishes after another Back, stops one stage up.
    func testARequestFromAStageNoLongerShownDoesNothing() {
        var flow = PlacesRoute.onExplanation(.business)
        XCTAssertTrue(flow.placesBack(from: .placeExplanation))
        let detail = flow
        XCTAssertFalse(flow.placesBack(from: .placeExplanation), "the repeated request is stale")
        XCTAssertEqual(flow, detail, "still Common Ground's detail")

        XCTAssertFalse(flow.placesBack(from: .places), "browsing is not current")
        XCTAssertEqual(flow, detail)
        XCTAssertTrue(flow.placesBack(from: .placeDetail))
        let browsing = flow
        XCTAssertFalse(flow.placesBack(from: .placeDetail))
        XCTAssertFalse(flow.placesBack(from: .placeExplanation))
        XCTAssertEqual(flow, browsing)
    }

    func testOutsidePlacesItDoesNothing() {
        let signal = PlacesRoute.onSignal(.social, approach: .chatFirst)
        for scene in DemoScene.allCases {
            var flow = signal
            XCTAssertFalse(flow.placesBack(from: scene), "\(scene) from Signal")
            XCTAssertEqual(flow, signal)
        }
        var welcome = DemoFlow()
        for scene in DemoScene.allCases {
            XCTAssertFalse(welcome.placesBack(from: scene), "\(scene) from Welcome")
        }
        XCTAssertEqual(welcome, DemoFlow())
    }

    /// Only the three Places scenes are ever routed; a non-Places scene passed while on Places
    /// changes nothing.
    func testOnlyPlacesScenesAreRouted() {
        let places = PlacesRoute.onPlaces(.activity, approach: .okayToSayHello)
        for scene in DemoScene.allCases where scene != .places {
            var flow = places
            XCTAssertFalse(flow.placesBack(from: scene), "\(scene)")
            XCTAssertEqual(flow, places)
        }
    }

    /// The navigation stack's own pop (what the system's escape or back gesture proposes when
    /// Places does not answer it) drops the inner stages: from a detail or the explanation it lands
    /// on Signal. This is the skip the shared route exists to avoid; kept as a record of why.
    func testAStackPopFromAnInnerStageSkipsToSignal() {
        var flow = PlacesRoute.onExplanation(.social)
        let stackPath = flow.path.filter { $0 != .placeDetail && $0 != .placeExplanation }
        XCTAssertTrue(flow.adoptNavigationPath(Array(stackPath.dropLast())))
        XCTAssertEqual(flow.currentScene, .signal, "a pop of the whole destination skips both inner stages")
    }
}

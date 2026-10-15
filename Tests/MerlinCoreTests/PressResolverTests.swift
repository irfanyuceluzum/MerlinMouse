import XCTest
@testable import MerlinCore

final class PressResolverTests: XCTestCase {
    func testSingleFingerLeftNoCandidate() {
        XCTAssertEqual(PressResolver.candidates(frontFingerXs: [0.1], fnDown: false, zoneWidth: 0.3), [])
    }

    func testNoFingersNoCandidate() {
        XCTAssertEqual(PressResolver.candidates(frontFingerXs: [], fnDown: false, zoneWidth: 0.3), [])
    }

    func testSingleFingerCenter() {
        XCTAssertEqual(PressResolver.candidates(frontFingerXs: [0.5], fnDown: false, zoneWidth: 0.3),
                       [Trigger(kind: .press, fingers: 1, zone: .center)])
    }

    func testSingleFingerRight() {
        XCTAssertEqual(PressResolver.candidates(frontFingerXs: [0.9], fnDown: false, zoneWidth: 0.3),
                       [Trigger(kind: .press, fingers: 1, zone: .right)])
    }

    func testFiveFingersCapsAtFour() {
        let c = PressResolver.candidates(frontFingerXs: [0.1, 0.2, 0.3, 0.4, 0.5], fnDown: false, zoneWidth: 0.3)
        XCTAssertEqual(c, [Trigger(kind: .press, fingers: 4)])
    }

    func testFnWithLeftFingerOnlyFn() {
        let c = PressResolver.candidates(frontFingerXs: [0.1], fnDown: true, zoneWidth: 0.3)
        XCTAssertEqual(c, [Trigger(kind: .press, fingers: 0, modifier: .fn)])
    }

    func testFnFirstThenFingers() {
        let c = PressResolver.candidates(frontFingerXs: [0.4, 0.6], fnDown: true, zoneWidth: 0.3)
        XCTAssertEqual(c, [Trigger(kind: .press, fingers: 0, modifier: .fn), Trigger(kind: .press, fingers: 2)])
    }

    func testZoneClassifyBoundaries() {
        // 0.25 / 0.75 / 0.5 ikilik tabanda tam gösterilir; sınır değerleri kesin.
        XCTAssertEqual(Zone.classify(x: 0.25, zoneWidth: 0.5), .center)
        XCTAssertEqual(Zone.classify(x: 0.75, zoneWidth: 0.5), .center)
        XCTAssertEqual(Zone.classify(x: 0.5, zoneWidth: 0.5), .center)
        XCTAssertEqual(Zone.classify(x: 0.2, zoneWidth: 0.5), .left)
        XCTAssertEqual(Zone.classify(x: 0.8, zoneWidth: 0.5), .right)
    }
}

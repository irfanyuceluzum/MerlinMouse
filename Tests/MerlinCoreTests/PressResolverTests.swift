import XCTest
@testable import MerlinCore

final class PressResolverTests: XCTestCase {
    private let std = ZoneLayout.symmetric(width: 0.3)

    private func pts(_ xs: [Float], y: Float = 0.7) -> [TouchPoint] {
        xs.enumerated().map { TouchPoint(id: Int32($0.offset + 1), x: $0.element, y: y) }
    }

    func testSingleFingerLeftNoCandidate() {
        XCTAssertEqual(PressResolver.candidates(fingers: pts([0.1]), fnDown: false, layout: std), [])
    }

    func testNoFingersNoCandidate() {
        XCTAssertEqual(PressResolver.candidates(fingers: [], fnDown: false, layout: std), [])
    }

    func testSingleFingerCenter() {
        XCTAssertEqual(PressResolver.candidates(fingers: pts([0.5]), fnDown: false, layout: std),
                       [Trigger(kind: .press, fingers: 1, zone: .center)])
    }

    func testSingleFingerRight() {
        XCTAssertEqual(PressResolver.candidates(fingers: pts([0.9]), fnDown: false, layout: std),
                       [Trigger(kind: .press, fingers: 1, zone: .right)])
    }

    func testRearFingerNeverCandidate() {
        XCTAssertEqual(PressResolver.candidates(fingers: pts([0.5], y: 0.2), fnDown: false, layout: std), [])
        // Avuç (arka) + ön tek parmak: yalnız öndeki sayılır.
        let mixed = pts([0.5], y: 0.2) + [TouchPoint(id: 9, x: 0.9, y: 0.8)]
        XCTAssertEqual(PressResolver.candidates(fingers: mixed, fnDown: false, layout: std),
                       [Trigger(kind: .press, fingers: 1, zone: .right)])
    }

    func testAsymmetricLayout() {
        let l = ZoneLayout(leftEdge: 0.2, rightEdge: 0.5, frontLimit: 0.4)
        XCTAssertEqual(PressResolver.candidates(fingers: pts([0.15]), fnDown: false, layout: l), [])
        XCTAssertEqual(PressResolver.candidates(fingers: pts([0.4]), fnDown: false, layout: l),
                       [Trigger(kind: .press, fingers: 1, zone: .center)])
        XCTAssertEqual(PressResolver.candidates(fingers: pts([0.6]), fnDown: false, layout: l),
                       [Trigger(kind: .press, fingers: 1, zone: .right)])
    }

    func testFiveFingersCapsAtFour() {
        let c = PressResolver.candidates(fingers: pts([0.1, 0.2, 0.3, 0.4, 0.5]), fnDown: false, layout: std)
        XCTAssertEqual(c, [Trigger(kind: .press, fingers: 4)])
    }

    func testFnWithLeftFingerOnlyFn() {
        let c = PressResolver.candidates(fingers: pts([0.1]), fnDown: true, layout: std)
        XCTAssertEqual(c, [Trigger(kind: .press, fingers: 0, modifier: .fn)])
    }

    func testFnFirstThenFingers() {
        let c = PressResolver.candidates(fingers: pts([0.4, 0.6]), fnDown: true, layout: std)
        XCTAssertEqual(c, [Trigger(kind: .press, fingers: 0, modifier: .fn), Trigger(kind: .press, fingers: 2)])
    }

    func testClassifyFourZonesAndBoundaries() {
        let l = ZoneLayout(leftEdge: 0.25, rightEdge: 0.75, frontLimit: 0.4)
        XCTAssertEqual(Zone.classify(x: 0.1, y: 0.7, layout: l), .left)
        XCTAssertEqual(Zone.classify(x: 0.5, y: 0.7, layout: l), .center)
        XCTAssertEqual(Zone.classify(x: 0.9, y: 0.7, layout: l), .right)
        XCTAssertEqual(Zone.classify(x: 0.5, y: 0.1, layout: l), .rear)
        XCTAssertEqual(Zone.classify(x: 0.05, y: 0.1, layout: l), .rear)
        // Sınırlar: leftEdge ve rightEdge orta bölgeye, frontLimit ön bölgeye dahil.
        XCTAssertEqual(Zone.classify(x: 0.25, y: 0.7, layout: l), .center)
        XCTAssertEqual(Zone.classify(x: 0.75, y: 0.7, layout: l), .center)
        XCTAssertEqual(Zone.classify(x: 0.1, y: 0.4, layout: l), .left)
        XCTAssertEqual(Zone.classify(x: 0.1, y: 0.399, layout: l), .rear)
    }

    func testClassifyAboveCenterTop() {
        let l = ZoneLayout(leftEdge: 0.25, rightEdge: 0.75, frontLimit: 0.4, centerTop: 0.8)
        XCTAssertEqual(Zone.classify(x: 0.4, y: 0.9, layout: l), .left)
        XCTAssertEqual(Zone.classify(x: 0.6, y: 0.9, layout: l), .right)
        XCTAssertEqual(Zone.classify(x: 0.5, y: 0.9, layout: l), .right) // tam orta çizgi sağa
        XCTAssertEqual(Zone.classify(x: 0.4, y: 0.7, layout: l), .center)
        XCTAssertEqual(Zone.classify(x: 0.4, y: 0.79, layout: l), .center)
        XCTAssertEqual(Zone.classify(x: 0.1, y: 0.9, layout: l), .left)
        XCTAssertEqual(Zone.classify(x: 0.9, y: 0.9, layout: l), .right)
        XCTAssertEqual(Zone.classify(x: 0.5, y: 0.3, layout: l), .rear)
        // centerTop 1.0: eski davranış.
        let old = ZoneLayout(leftEdge: 0.25, rightEdge: 0.75, frontLimit: 0.4)
        XCTAssertEqual(Zone.classify(x: 0.4, y: 1.0, layout: old), .center)
        XCTAssertEqual(Zone.classify(x: 0.6, y: 1.0, layout: old), .center)
    }

    func testPressInCenterTopLeftHalfNoCandidate() {
        let l = ZoneLayout(leftEdge: 0.25, rightEdge: 0.75, frontLimit: 0.4, centerTop: 0.8)
        XCTAssertEqual(PressResolver.candidates(fingers: [TouchPoint(id: 1, x: 0.4, y: 0.9)], fnDown: false, layout: l), [])
        XCTAssertEqual(PressResolver.candidates(fingers: [TouchPoint(id: 1, x: 0.6, y: 0.9)], fnDown: false, layout: l),
                       [Trigger(kind: .press, fingers: 1, zone: .right)])
        XCTAssertEqual(PressResolver.candidates(fingers: [TouchPoint(id: 1, x: 0.4, y: 0.7)], fnDown: false, layout: l),
                       [Trigger(kind: .press, fingers: 1, zone: .center)])
    }
}

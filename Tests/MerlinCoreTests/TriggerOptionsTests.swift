import XCTest
@testable import MerlinCore

final class TriggerOptionsTests: XCTestCase {
    func testEditableKinds() {
        XCTAssertEqual(TriggerOptions.editableKinds, [.press, .tap, .doubleTap, .swipe, .pinch, .edgeSlide])
    }

    func testEdgeSlideOptions() {
        XCTAssertEqual(TriggerOptions.fingerChoices(kind: .edgeSlide), [1])
        XCTAssertEqual(TriggerOptions.zoneChoices(kind: .edgeSlide, fingers: 1, modifier: .none), [.leftEdge, .rightEdge])
        XCTAssertEqual(TriggerOptions.modifierChoices(kind: .edgeSlide), [.none])
        let t = TriggerOptions.sanitize(Trigger(kind: .edgeSlide, fingers: 3, zone: .center, direction: .left, modifier: .fn))
        XCTAssertEqual(t, Trigger(kind: .edgeSlide, fingers: 1, zone: .leftEdge))
        XCTAssertEqual(TriggerOptions.sanitize(Trigger(kind: .edgeSlide, zone: .rightEdge)).zone, .rightEdge)
        // Diğer türlerin seçeneklerinde kenar yok.
        for k in TriggerOptions.editableKinds where k != .edgeSlide {
            for f in 0...4 {
                for m in PressModifier.allCases {
                    XCTAssertFalse(TriggerOptions.zoneChoices(kind: k, fingers: f, modifier: m).contains { $0.isEdge }, "\(k)")
                }
            }
        }
        // Başka türde kenar bölgesi "her yer"e çekilir.
        XCTAssertEqual(TriggerOptions.sanitize(Trigger(kind: .doubleTap, fingers: 1, zone: .leftEdge)).zone, .any)
    }

    func testPinchOptions() {
        XCTAssertEqual(TriggerOptions.fingerChoices(kind: .pinch), [2])
        XCTAssertTrue(TriggerOptions.zoneChoices(kind: .pinch, fingers: 2, modifier: .none).isEmpty)
        XCTAssertEqual(TriggerOptions.modifierChoices(kind: .pinch), [.none])
        let t = TriggerOptions.sanitize(Trigger(kind: .pinch, fingers: 3, zone: .right, direction: .left, modifier: .fn))
        XCTAssertEqual(t, Trigger(kind: .pinch, fingers: 2))
    }

    func testFingerChoices() {
        XCTAssertEqual(TriggerOptions.fingerChoices(kind: .press), [1, 2, 3, 4])
        XCTAssertEqual(TriggerOptions.fingerChoices(kind: .tap), [1, 2, 3, 4])
        XCTAssertEqual(TriggerOptions.fingerChoices(kind: .doubleTap), [1, 2, 3, 4])
        XCTAssertEqual(TriggerOptions.fingerChoices(kind: .swipe), [3, 4])
    }

    func testZoneChoices() {
        XCTAssertEqual(TriggerOptions.zoneChoices(kind: .press, fingers: 1, modifier: .none), [.center, .right])
        XCTAssertEqual(TriggerOptions.zoneChoices(kind: .doubleTap, fingers: 1, modifier: .none),
                       [.any, .left, .center, .right, .rear])
        XCTAssertTrue(TriggerOptions.zoneChoices(kind: .press, fingers: 2, modifier: .none).isEmpty)
        XCTAssertTrue(TriggerOptions.zoneChoices(kind: .press, fingers: 1, modifier: .fn).isEmpty)
        XCTAssertEqual(TriggerOptions.zoneChoices(kind: .tap, fingers: 1, modifier: .none), [.rear])
        XCTAssertTrue(TriggerOptions.zoneChoices(kind: .tap, fingers: 2, modifier: .none).isEmpty)
        XCTAssertFalse(TriggerOptions.zoneChoices(kind: .press, fingers: 1, modifier: .none).contains(.rear))
        XCTAssertTrue(TriggerOptions.zoneChoices(kind: .swipe, fingers: 1, modifier: .none).isEmpty)
    }

    func testModifierChoices() {
        XCTAssertEqual(TriggerOptions.modifierChoices(kind: .press), [.none, .fn, .option, .command, .shift])
        XCTAssertEqual(TriggerOptions.modifierChoices(kind: .tap), [.none])
        XCTAssertEqual(TriggerOptions.modifierChoices(kind: .doubleTap), [.none])
        XCTAssertEqual(TriggerOptions.modifierChoices(kind: .swipe), [.none])
    }

    func testSanitize() {
        let tap1 = TriggerOptions.sanitize(Trigger(kind: .tap, fingers: 1))
        XCTAssertEqual(tap1.fingers, 1)
        XCTAssertEqual(tap1.zone, .rear)
        XCTAssertEqual(TriggerOptions.sanitize(Trigger(kind: .tap, fingers: 5)).fingers, 1)
        XCTAssertEqual(TriggerOptions.sanitize(Trigger(kind: .swipe, fingers: 2)).fingers, 3)
        let p = TriggerOptions.sanitize(Trigger(kind: .press, fingers: 1, zone: .left))
        XCTAssertEqual(p.fingers, 1)
        XCTAssertEqual(p.zone, .center)
        let f = TriggerOptions.sanitize(Trigger(kind: .press, fingers: 1, zone: .center, modifier: .fn))
        XCTAssertEqual(f.fingers, 0)
        XCTAssertEqual(f.zone, .any)
        XCTAssertEqual(f.modifier, .fn)
    }

    func testSanitizeDropsInvalidModifierAndZone() {
        let t = TriggerOptions.sanitize(Trigger(kind: .tap, fingers: 2, zone: .right, modifier: .shift))
        XCTAssertEqual(t, Trigger(kind: .tap, fingers: 2))
        let d = TriggerOptions.sanitize(Trigger(kind: .doubleTap, fingers: 1, zone: .left))
        XCTAssertEqual(d.zone, .left)
    }
}

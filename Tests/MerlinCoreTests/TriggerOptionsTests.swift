import XCTest
@testable import MerlinCore

final class TriggerOptionsTests: XCTestCase {
    func testEditableKinds() {
        XCTAssertEqual(TriggerOptions.editableKinds, [.press, .tap, .doubleTap, .swipe])
    }

    func testFingerChoices() {
        XCTAssertEqual(TriggerOptions.fingerChoices(kind: .press), [1, 2, 3, 4])
        XCTAssertEqual(TriggerOptions.fingerChoices(kind: .tap), [2, 3, 4])
        XCTAssertEqual(TriggerOptions.fingerChoices(kind: .doubleTap), [1, 2, 3, 4])
        XCTAssertEqual(TriggerOptions.fingerChoices(kind: .swipe), [3, 4])
    }

    func testZoneChoices() {
        XCTAssertEqual(TriggerOptions.zoneChoices(kind: .press, fingers: 1, modifier: .none), [.center, .right])
        XCTAssertEqual(TriggerOptions.zoneChoices(kind: .doubleTap, fingers: 1, modifier: .none),
                       [.any, .left, .center, .right])
        XCTAssertTrue(TriggerOptions.zoneChoices(kind: .press, fingers: 2, modifier: .none).isEmpty)
        XCTAssertTrue(TriggerOptions.zoneChoices(kind: .press, fingers: 1, modifier: .fn).isEmpty)
        XCTAssertTrue(TriggerOptions.zoneChoices(kind: .tap, fingers: 1, modifier: .none).isEmpty)
        XCTAssertTrue(TriggerOptions.zoneChoices(kind: .swipe, fingers: 1, modifier: .none).isEmpty)
    }

    func testModifierChoices() {
        XCTAssertEqual(TriggerOptions.modifierChoices(kind: .press), [.none, .fn, .option, .command, .shift])
        XCTAssertEqual(TriggerOptions.modifierChoices(kind: .tap), [.none])
        XCTAssertEqual(TriggerOptions.modifierChoices(kind: .doubleTap), [.none])
        XCTAssertEqual(TriggerOptions.modifierChoices(kind: .swipe), [.none])
    }

    func testSanitize() {
        XCTAssertEqual(TriggerOptions.sanitize(Trigger(kind: .tap, fingers: 1)).fingers, 2)
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

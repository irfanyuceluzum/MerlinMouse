import XCTest
@testable import MerlinCore

final class BatteryAlertPolicyTests: XCTestCase {
    func testKindBoundaries() {
        XCTAssertEqual(BatteryAlertPolicy.kind(percent: 100), .normal)
        XCTAssertEqual(BatteryAlertPolicy.kind(percent: 21), .normal)
        XCTAssertEqual(BatteryAlertPolicy.kind(percent: 20), .low)
        XCTAssertEqual(BatteryAlertPolicy.kind(percent: 11), .low)
        XCTAssertEqual(BatteryAlertPolicy.kind(percent: 10), .critical)
        XCTAssertEqual(BatteryAlertPolicy.kind(percent: 0), .critical)
    }

    func testStepwiseDrop() {
        var p = BatteryAlertPolicy()
        XCTAssertNil(p.update(percent: 21))
        XCTAssertEqual(p.update(percent: 20), 20)
        XCTAssertNil(p.update(percent: 19))
        XCTAssertEqual(p.update(percent: 10), 10)
        XCTAssertNil(p.update(percent: 9))
    }

    func testDirectDropNotifiesOnlyLowest() {
        var p = BatteryAlertPolicy()
        XCTAssertNil(p.update(percent: 25))
        XCTAssertEqual(p.update(percent: 8), 10)
        XCTAssertEqual(p.notified, [10, 20])
        XCTAssertNil(p.update(percent: 7))
    }

    func testChargingResets() {
        var p = BatteryAlertPolicy()
        XCTAssertEqual(p.update(percent: 8), 10)
        XCTAssertNil(p.update(percent: 15))
        XCTAssertEqual(p.notified, [20])
        XCTAssertEqual(p.update(percent: 10), 10)
        XCTAssertNil(p.update(percent: 26))
        XCTAssertTrue(p.notified.isEmpty)
        XCTAssertEqual(p.update(percent: 20), 20)
    }

    func testLoadedNotifiedPersists() {
        var p = BatteryAlertPolicy(notified: [20])
        XCTAssertNil(p.update(percent: 19))
    }

    func testSymbolRanges() {
        XCTAssertEqual(BatteryAlertPolicy.symbolName(percent: 100), "battery.100")
        XCTAssertEqual(BatteryAlertPolicy.symbolName(percent: 88), "battery.100")
        XCTAssertEqual(BatteryAlertPolicy.symbolName(percent: 87), "battery.75")
        XCTAssertEqual(BatteryAlertPolicy.symbolName(percent: 63), "battery.75")
        XCTAssertEqual(BatteryAlertPolicy.symbolName(percent: 62), "battery.50")
        XCTAssertEqual(BatteryAlertPolicy.symbolName(percent: 38), "battery.50")
        XCTAssertEqual(BatteryAlertPolicy.symbolName(percent: 37), "battery.25")
        XCTAssertEqual(BatteryAlertPolicy.symbolName(percent: 13), "battery.25")
        XCTAssertEqual(BatteryAlertPolicy.symbolName(percent: 12), "battery.0")
    }

    func testIsMagicMouse() {
        XCTAssertTrue(MagicMouseIDs.isMagicMouse(vendorID: 76, productID: 0x0323))
        XCTAssertTrue(MagicMouseIDs.isMagicMouse(vendorID: 76, productID: 0x030D))
        XCTAssertTrue(MagicMouseIDs.isMagicMouse(vendorID: 76, productID: 0x0269))
        XCTAssertFalse(MagicMouseIDs.isMagicMouse(vendorID: 76, productID: 0x0324))
        XCTAssertFalse(MagicMouseIDs.isMagicMouse(vendorID: 1, productID: 0x0323))
    }
}

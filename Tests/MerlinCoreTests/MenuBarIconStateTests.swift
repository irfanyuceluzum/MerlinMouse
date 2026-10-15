import XCTest
@testable import MerlinCore

final class MenuBarIconStateTests: XCTestCase {
    private func r(_ e: Bool = true, _ p: Bool = false, _ t: Bool = true, b: Int? = nil) -> MenuBarIconState {
        MenuBarIconState.resolve(enabled: e, paused: p, trusted: t, batteryPercent: b)
    }

    func testNormal() {
        XCTAssertEqual(r(), .normal)
        XCTAssertEqual(r(b: 21), .normal)
    }

    func testPriority() {
        XCTAssertEqual(r(false, true, false, b: 5), .disabled)
        XCTAssertEqual(r(true, true, false, b: 5), .paused)
        XCTAssertEqual(r(true, false, false, b: 5), .noPermission)
        XCTAssertEqual(r(b: 10), .criticalBattery)
        XCTAssertEqual(r(b: 11), .lowBattery)
        XCTAssertEqual(r(b: 20), .lowBattery)
    }

    func testSymbolsAndHelp() {
        XCTAssertEqual(MenuBarIconState.normal.symbolName, "magicmouse")
        XCTAssertEqual(MenuBarIconState.disabled.symbolName, "magicmouse")
        XCTAssertEqual(MenuBarIconState.paused.symbolName, "pause.circle")
        XCTAssertEqual(MenuBarIconState.noPermission.symbolName, "exclamationmark.triangle")
        XCTAssertEqual(MenuBarIconState.lowBattery.symbolName, "battery.25")
        XCTAssertEqual(MenuBarIconState.criticalBattery.symbolName, "battery.0")
        for s in [MenuBarIconState.normal, .disabled, .paused, .noPermission, .lowBattery, .criticalBattery] {
            XCTAssertFalse(s.help.isEmpty)
        }
    }
}

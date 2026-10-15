import XCTest
@testable import MerlinCore

final class SystemGestureCatalogTests: XCTestCase {
    func testDefaultEnvironment() {
        let rows = SystemGestureCatalog.rows(env: ConflictEnvironment())
        XCTAssertEqual(rows.count, 6)
        XCTAssertEqual(rows.map(\.isOn), [false, false, false, false, true, true])
        XCTAssertFalse(rows.contains { $0.gesture == "BetterTouchTool" })
        XCTAssertEqual(rows[0].note, "Kullanılabilir; macOS'ta açılırsa uyarı verilir")
        XCTAssertEqual(rows[4].note, "Ayrılmış, atanamaz")
    }

    func testBusyEnvironmentWithBTT() {
        let env = ConflictEnvironment(mouseButtonMode: "TwoButton", oneFingerDoubleTap: 1,
                                      twoFingerDoubleTap: 3, twoFingerHorizSwipe: 2, bttRunning: true)
        let rows = SystemGestureCatalog.rows(env: env)
        XCTAssertEqual(rows.count, 7)
        XCTAssertEqual(rows.map(\.isOn), [true, true, true, true, true, true, true])
        XCTAssertEqual(rows[0].note, "Atanırsa uyarı verilir")
        XCTAssertEqual(rows.last?.gesture, "BetterTouchTool")
        XCTAssertEqual(rows.last?.task, "2 ve 3 parmak tıklaması atanmış olabilir")
    }

    func testMouseButtonModeOneButtonIsOff() {
        let rows = SystemGestureCatalog.rows(env: ConflictEnvironment(mouseButtonMode: "OneButton"))
        XCTAssertFalse(rows[0].isOn)
    }

    func testConfigurableFlags() {
        let rows = SystemGestureCatalog.rows(env: ConflictEnvironment(bttRunning: true))
        XCTAssertEqual(rows.map(\.isConfigurable), [true, true, true, true, false, false, false])
    }
}

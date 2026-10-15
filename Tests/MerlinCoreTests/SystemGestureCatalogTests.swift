import XCTest
@testable import MerlinCore

final class SystemGestureCatalogTests: XCTestCase {
    func testDefaultEnvironment() {
        let rows = SystemGestureCatalog.rows(env: ConflictEnvironment())
        XCTAssertEqual(rows.count, 9)
        XCTAssertEqual(rows.map(\.status), [.off, .off, .off, .off, .off, .always, .always, .off, .appLevel])
        XCTAssertFalse(rows.contains { $0.gesture == "BetterTouchTool" })
        XCTAssertEqual(rows[0].note, "Kullanılabilir; macOS'ta açılırsa uyarı verilir")
        XCTAssertEqual(rows[5].note, "Orta tuşla sürüklerken engellenir")
        XCTAssertEqual(rows[6].note, "Ayrılmış, atanamaz")
        XCTAssertEqual(rows[8].note, "Profil başına kontrol edilir")
        XCTAssertEqual(rows.map(\.isOn), [false, false, false, false, false, true, true, false, false])
    }

    func testBusyEnvironmentWithBTT() {
        let env = ConflictEnvironment(mouseButtonMode: "TwoButton", oneFingerDoubleTap: 1,
                                      twoFingerDoubleTap: 3, twoFingerHorizSwipe: 2, bttRunning: true,
                                      oneFingerHorizSwipePages: 1, controlScrollZoom: true)
        let rows = SystemGestureCatalog.rows(env: env)
        XCTAssertEqual(rows.count, 10)
        XCTAssertEqual(rows.map(\.status), [.on, .on, .on, .on, .on, .always, .always, .on, .appLevel, .on])
        XCTAssertEqual(rows[0].note, "Çakışır, atanırsa uyarı verilir")
        XCTAssertEqual(rows.last?.gesture, "BetterTouchTool")
        XCTAssertEqual(rows.last?.task, "2 ve 3 parmak tıklaması atanmış olabilir")
        XCTAssertEqual(SystemGestureCatalog.conflictCount(env: env), 6)
    }

    func testConflictCountDefaultIsZero() {
        XCTAssertEqual(SystemGestureCatalog.conflictCount(env: ConflictEnvironment(bttRunning: true)), 0)
        XCTAssertEqual(SystemGestureCatalog.conflictCount(env: ConflictEnvironment(controlScrollZoom: true)), 1)
    }

    func testMouseButtonModeOneButtonIsOff() {
        let rows = SystemGestureCatalog.rows(env: ConflictEnvironment(mouseButtonMode: "OneButton"))
        XCTAssertEqual(rows[0].status, .off)
    }

    func testConfigurableFlags() {
        let rows = SystemGestureCatalog.rows(env: ConflictEnvironment(bttRunning: true))
        XCTAssertEqual(rows.map(\.isConfigurable),
                       [true, true, true, true, true, false, false, true, false, false])
    }

    func testFreeGestures() {
        XCTAssertEqual(SystemGestureCatalog.freeGestures.count, 5)
        XCTAssertEqual(SystemGestureCatalog.freeGestures.last, "Fn + tıklama / sürükleme")
    }
}

import XCTest
@testable import MerlinCore

final class GesturePresetsTests: XCTestCase {
    func testOrderAndCount() {
        XCTAssertEqual(GesturePresets.all.count, 12)
        XCTAssertEqual(GesturePresets.all.first?.title, "Orta bölgeye bas")
        XCTAssertEqual(GesturePresets.all.last?.title, "Üç parmakla sağa kaydır")
    }

    func testNoneReservedOrUnsupported() {
        for p in GesturePresets.all {
            let probe = GestureBinding(trigger: p.trigger, action: .middleClick)
            let conflicts = ConflictChecker.check(probe, among: [], env: ConflictEnvironment())
            XCTAssertFalse(conflicts.contains { $0.level == .reserved || $0.level == .unsupported }, p.title)
        }
    }
}

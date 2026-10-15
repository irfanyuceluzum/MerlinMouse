import XCTest
@testable import MerlinCore

final class BindingStatusTests: XCTestCase {
    private func c(_ l: ConflictLevel) -> Conflict { Conflict(level: l, title: "", detail: "") }

    func testDisabledWins() {
        XCTAssertEqual(BindingStatus.kind(enabled: false, conflicts: [c(.reserved), c(.macOS)]), .disabled)
    }

    func testBlockingLevels() {
        for l in [ConflictLevel.reserved, .unsupported, .duplicate] {
            XCTAssertEqual(BindingStatus.kind(enabled: true, conflicts: [c(.macOS), c(l)]), .blocked)
        }
    }

    func testPriorityOrder() {
        XCTAssertEqual(BindingStatus.kind(enabled: true, conflicts: [c(.caution), c(.shadows), c(.btt), c(.macOS)]), .macOS)
        XCTAssertEqual(BindingStatus.kind(enabled: true, conflicts: [c(.caution), c(.shadows), c(.btt)]), .btt)
        XCTAssertEqual(BindingStatus.kind(enabled: true, conflicts: [c(.caution), c(.shadows)]), .shadows)
        XCTAssertEqual(BindingStatus.kind(enabled: true, conflicts: [c(.caution)]), .caution)
    }

    func testFree() {
        XCTAssertEqual(BindingStatus.kind(enabled: true, conflicts: []), .free)
    }
}

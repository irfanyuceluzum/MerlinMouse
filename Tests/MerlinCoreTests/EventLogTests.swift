import XCTest
@testable import MerlinCore

final class EventLogTests: XCTestCase {
    func testNewestFirst() {
        var log = EventLog()
        log.append(EventLogEntry(text: "a", dryRun: false))
        log.append(EventLogEntry(text: "b", dryRun: true))
        XCTAssertEqual(log.entries.map(\.text), ["b", "a"])
        XCTAssertTrue(log.entries[0].dryRun)
    }

    func testCapacityDropsOldest() {
        var log = EventLog()
        XCTAssertEqual(log.capacity, 12)
        for i in 0..<20 { log.append(EventLogEntry(text: "\(i)", dryRun: false)) }
        XCTAssertEqual(log.entries.count, 12)
        XCTAssertEqual(log.entries.first?.text, "19")
        XCTAssertEqual(log.entries.last?.text, "8")
    }

    func testClear() {
        var log = EventLog(capacity: 3)
        log.append(EventLogEntry(text: "x", dryRun: false))
        log.clear()
        XCTAssertTrue(log.entries.isEmpty)
    }
}

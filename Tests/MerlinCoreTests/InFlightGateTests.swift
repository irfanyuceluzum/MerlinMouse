import XCTest
@testable import MerlinCore

final class InFlightGateTests: XCTestCase {
    func testSameKeyRejectedUntilEnd() {
        let gate = InFlightGate<String>()
        XCTAssertTrue(gate.tryBegin("A"))
        XCTAssertTrue(gate.isRunning("A"))
        XCTAssertFalse(gate.tryBegin("A"))
        gate.end("A")
        XCTAssertFalse(gate.isRunning("A"))
        XCTAssertTrue(gate.tryBegin("A"))
    }

    func testDifferentKeysIndependent() {
        let gate = InFlightGate<String>()
        XCTAssertTrue(gate.tryBegin("A"))
        XCTAssertTrue(gate.tryBegin("B"))
        gate.end("A")
        XCTAssertTrue(gate.isRunning("B"))
        XCTAssertFalse(gate.tryBegin("B"))
    }

    func testFirstRejectionReportedOncePerRun() {
        let gate = InFlightGate<String>()
        XCTAssertEqual(gate.admit("A"), .begun)
        XCTAssertEqual(gate.admit("A"), .busy(firstRejection: true))
        XCTAssertEqual(gate.admit("A"), .busy(firstRejection: false))
        gate.end("A")
        XCTAssertEqual(gate.admit("A"), .begun)
        XCTAssertEqual(gate.admit("A"), .busy(firstRejection: true))
    }

    func testEndCalledOnErrorPath() {
        let gate = InFlightGate<String>()
        struct Failure: Error {}
        func run() throws {
            guard gate.tryBegin("A") else { return }
            defer { gate.end("A") }
            throw Failure()
        }
        XCTAssertThrowsError(try run())
        XCTAssertFalse(gate.isRunning("A"))
    }

    func testConcurrentBeginsAdmitExactlyOne() {
        let gate = InFlightGate<String>()
        let lock = NSLock()
        var admitted = 0
        DispatchQueue.concurrentPerform(iterations: 200) { _ in
            if gate.tryBegin("A") {
                lock.lock(); admitted += 1; lock.unlock()
            }
        }
        XCTAssertEqual(admitted, 1)
        gate.end("A")
        XCTAssertTrue(gate.tryBegin("A"))
    }
}

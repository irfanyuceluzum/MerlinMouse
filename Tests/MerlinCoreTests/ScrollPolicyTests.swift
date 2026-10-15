import XCTest
@testable import MerlinCore

final class ScrollPolicyTests: XCTestCase {
    func testMiddleDragBlock() {
        XCTAssertTrue(ScrollPolicy.shouldDrop(middleDragActive: true, blockWhileDragging: true,
                                              calm3D: false, frontIs3D: false, momentumPhase: 0))
        XCTAssertFalse(ScrollPolicy.shouldDrop(middleDragActive: true, blockWhileDragging: false,
                                               calm3D: false, frontIs3D: false, momentumPhase: 0))
        XCTAssertFalse(ScrollPolicy.shouldDrop(middleDragActive: false, blockWhileDragging: true,
                                               calm3D: false, frontIs3D: false, momentumPhase: 0))
    }

    func testCalm3DMomentum() {
        XCTAssertTrue(ScrollPolicy.shouldDrop(middleDragActive: false, blockWhileDragging: true,
                                              calm3D: true, frontIs3D: true, momentumPhase: 2))
        XCTAssertFalse(ScrollPolicy.shouldDrop(middleDragActive: false, blockWhileDragging: true,
                                               calm3D: true, frontIs3D: true, momentumPhase: 0))
        XCTAssertFalse(ScrollPolicy.shouldDrop(middleDragActive: false, blockWhileDragging: true,
                                               calm3D: true, frontIs3D: false, momentumPhase: 2))
        XCTAssertFalse(ScrollPolicy.shouldDrop(middleDragActive: false, blockWhileDragging: true,
                                               calm3D: false, frontIs3D: true, momentumPhase: 2))
    }

    func testPinchDropsRegardlessOfSettings() {
        XCTAssertTrue(ScrollPolicy.shouldDrop(middleDragActive: false, blockWhileDragging: false,
                                              calm3D: false, frontIs3D: false, momentumPhase: 0, pinchActive: true))
        XCTAssertFalse(ScrollPolicy.shouldDrop(middleDragActive: false, blockWhileDragging: false,
                                               calm3D: false, frontIs3D: false, momentumPhase: 0, pinchActive: false))
    }
}

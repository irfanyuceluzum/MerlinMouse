import XCTest
@testable import MerlinCore

final class AlphaBoundsTests: XCTestCase {
    func testEmptyImageIsNil() {
        XCTAssertNil(AlphaBounds.opaqueRect(width: 4, height: 3, alpha: [UInt8](repeating: 0, count: 12), threshold: 200))
    }

    func testFullyOpaqueIsWholeImage() {
        let r = AlphaBounds.opaqueRect(width: 4, height: 3, alpha: [UInt8](repeating: 255, count: 12), threshold: 200)
        XCTAssertEqual(r?.x, 0); XCTAssertEqual(r?.y, 0)
        XCTAssertEqual(r?.width, 4); XCTAssertEqual(r?.height, 3)
    }

    func testBoxInTheMiddle() {
        var a = [UInt8](repeating: 0, count: 5 * 5)
        for y in 1...2 { for x in 2...3 { a[y * 5 + x] = 255 } }
        let r = AlphaBounds.opaqueRect(width: 5, height: 5, alpha: a, threshold: 200)
        XCTAssertEqual(r?.x, 2); XCTAssertEqual(r?.y, 1)
        XCTAssertEqual(r?.width, 2); XCTAssertEqual(r?.height, 2)
    }

    func testShadowBelowThresholdIgnored() {
        var a = [UInt8](repeating: 90, count: 5 * 5)
        a[2 * 5 + 2] = 255
        let r = AlphaBounds.opaqueRect(width: 5, height: 5, alpha: a, threshold: 200)
        XCTAssertEqual(r?.x, 2); XCTAssertEqual(r?.y, 2)
        XCTAssertEqual(r?.width, 1); XCTAssertEqual(r?.height, 1)
        a[0] = 200 // eşit olan sayılmaz
        XCTAssertEqual(AlphaBounds.opaqueRect(width: 5, height: 5, alpha: a, threshold: 200)?.x, 2)
    }
}

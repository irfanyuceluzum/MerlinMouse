import XCTest
@testable import MerlinCore

final class ZoneLayoutTests: XCTestCase {
    func testStandard() {
        XCTAssertEqual(ZoneLayout.standard.leftEdge, 0.35, accuracy: 1e-9)
        XCTAssertEqual(ZoneLayout.standard.rightEdge, 0.65, accuracy: 1e-9)
        XCTAssertEqual(ZoneLayout.standard.frontLimit, 0.4)
        XCTAssertEqual(ZoneLayout.standard.centerWidth, 0.30, accuracy: 1e-9)
        XCTAssertEqual(ZoneLayout.standard.leftWidth, 0.35, accuracy: 1e-9)
        XCTAssertEqual(ZoneLayout.standard.rightWidth, 0.35, accuracy: 1e-9)
    }

    func testClampKeepsValidLayout() {
        let l = ZoneLayout(leftEdge: 0.3, rightEdge: 0.6, frontLimit: 0.5)
        XCTAssertEqual(l.clamped(), l)
    }

    func testClampMinimumWidths() {
        let l = ZoneLayout(leftEdge: 0.0, rightEdge: 0.02, frontLimit: 0.0).clamped()
        XCTAssertGreaterThanOrEqual(l.leftWidth, 0.10 - 1e-9)
        XCTAssertGreaterThanOrEqual(l.centerWidth, 0.10 - 1e-9)
        XCTAssertGreaterThanOrEqual(l.rightWidth, 0.10 - 1e-9)
        XCTAssertEqual(l.frontLimit, 0.2)
    }

    func testClampUpperBounds() {
        let l = ZoneLayout(leftEdge: 0.95, rightEdge: 1.5, frontLimit: 0.9).clamped()
        XCTAssertLessThanOrEqual(l.rightEdge, 0.90 + 1e-9)
        XCTAssertGreaterThanOrEqual(l.centerWidth, 0.10 - 1e-9)
        XCTAssertLessThanOrEqual(l.leftEdge, 0.80 + 1e-9)
        XCTAssertEqual(l.frontLimit, 0.6)
    }

    func testFromLegacy() {
        let l = ZoneLayout.fromLegacy(zoneWidth: 0.30)
        XCTAssertEqual(l.leftEdge, 0.35, accuracy: 1e-9)
        XCTAssertEqual(l.rightEdge, 0.65, accuracy: 1e-9)
        XCTAssertEqual(l.frontLimit, 0.4)
        // Aşırı geniş eski değer sınırlanır.
        let wide = ZoneLayout.fromLegacy(zoneWidth: 1.0)
        XCTAssertGreaterThanOrEqual(wide.leftWidth, 0.10 - 1e-9)
        XCTAssertGreaterThanOrEqual(wide.rightWidth, 0.10 - 1e-9)
    }

    func testCodableRoundTrip() throws {
        let l = ZoneLayout(leftEdge: 0.2, rightEdge: 0.7, frontLimit: 0.3)
        let data = try JSONEncoder().encode(l)
        XCTAssertEqual(try JSONDecoder().decode(ZoneLayout.self, from: data), l)
    }

    func testZoneRearJSON() throws {
        let data = try JSONEncoder().encode(Trigger(kind: .tap, fingers: 1, zone: .rear))
        XCTAssertTrue(String(data: data, encoding: .utf8)!.contains("\"rear\""))
        let back = try JSONDecoder().decode(Trigger.self, from: data)
        XCTAssertEqual(back.zone, .rear)
        XCTAssertEqual(Zone.rear.rawValue, "rear")
        XCTAssertEqual(Zone.rear.displayName, "Arka (logo)")
    }

    func testRearTitles() {
        XCTAssertEqual(Trigger(kind: .tap, fingers: 1, zone: .rear).title, "Arkaya dokun")
        XCTAssertEqual(Trigger(kind: .doubleTap, fingers: 1, zone: .rear).title, "Arkaya çift dokun")
        XCTAssertEqual(Trigger(kind: .tap, fingers: 2, zone: .rear).normalized.zone, .any)
    }

    func testMovingLeft() {
        let l = ZoneLayout.standard.moving(.left, to: 0.25)
        XCTAssertEqual(l.leftEdge, 0.25, accuracy: 1e-9)
        XCTAssertEqual(l.rightEdge, 0.65, accuracy: 1e-9)
    }

    func testMovingRight() {
        let l = ZoneLayout.standard.moving(.right, to: 0.75)
        XCTAssertEqual(l.rightEdge, 0.75, accuracy: 1e-9)
        XCTAssertEqual(l.leftEdge, 0.35, accuracy: 1e-9)
    }

    func testMovingFront() {
        let l = ZoneLayout.standard.moving(.front, to: 0.5)
        XCTAssertEqual(l.frontLimit, 0.5, accuracy: 1e-9)
        XCTAssertEqual(l.leftEdge, 0.35, accuracy: 1e-9)
    }

    func testMovingLeftCannotPassRight() {
        let l = ZoneLayout.standard.moving(.left, to: 0.9)
        XCTAssertEqual(l.leftEdge, 0.65 - 0.10, accuracy: 1e-9)
        XCTAssertEqual(l.rightEdge, 0.65, accuracy: 1e-9)
    }

    func testMovingRightCannotPassLeft() {
        let l = ZoneLayout.standard.moving(.right, to: 0.0)
        XCTAssertEqual(l.rightEdge, 0.35 + 0.10, accuracy: 1e-9)
        XCTAssertEqual(l.leftEdge, 0.35, accuracy: 1e-9)
    }

    func testMovingClampsRanges() {
        XCTAssertEqual(ZoneLayout.standard.moving(.left, to: -1).leftEdge, 0.10, accuracy: 1e-9)
        XCTAssertEqual(ZoneLayout.standard.moving(.right, to: 5).rightEdge, 0.90, accuracy: 1e-9)
        XCTAssertEqual(ZoneLayout.standard.moving(.front, to: 0.0).frontLimit, 0.2)
        XCTAssertEqual(ZoneLayout.standard.moving(.front, to: 1.0).frontLimit, 0.6)
    }
}

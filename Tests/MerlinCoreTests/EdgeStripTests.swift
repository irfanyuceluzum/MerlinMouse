import XCTest
@testable import MerlinCore

final class EdgeStripTests: XCTestCase {
    private func p(_ id: Int32, _ x: Float, _ y: Float) -> TouchPoint { TouchPoint(id: id, x: x, y: y) }

    // MARK: Dikey aralık

    func testDefaults() {
        let s = EdgeStripBounds.standard
        XCTAssertEqual(s.bottom, 0.15)
        XCTAssertEqual(s.top, 0.60)
        XCTAssertEqual(s.clamped(), s)
        XCTAssertTrue(s.contains(y: 0.4))
        XCTAssertFalse(s.contains(y: 0.7))
        XCTAssertFalse(s.contains(y: 0.1))
    }

    func testClamped() {
        XCTAssertEqual(EdgeStripBounds(bottom: -0.2, top: 0.95).clamped(), EdgeStripBounds(bottom: 0, top: 0.85))
        // En az yükseklik: alt uç aşağı itilir.
        let short = EdgeStripBounds(bottom: 0.5, top: 0.55).clamped()
        XCTAssertEqual(short.bottom, 0.40, accuracy: 1e-9)
        XCTAssertEqual(short.top, 0.55)
        // Ters sıra ve çok alçak üst uç.
        let low = EdgeStripBounds(bottom: 0.3, top: 0.05).clamped()
        XCTAssertEqual(low.bottom, 0, accuracy: 1e-9)
        XCTAssertEqual(low.top, 0.15, accuracy: 1e-9)
        for b in stride(from: -0.5, through: 1.5, by: 0.1) {
            for t in stride(from: -0.5, through: 1.5, by: 0.1) {
                let c = EdgeStripBounds(bottom: b, top: t).clamped()
                XCTAssertGreaterThanOrEqual(c.bottom, 0)
                XCTAssertLessThanOrEqual(c.top, EdgeStripBounds.maxTop)
                XCTAssertGreaterThanOrEqual(c.height, EdgeStripBounds.minHeight - 1e-9)
            }
        }
    }

    func testMovingEnds() {
        let s = EdgeStripBounds.standard
        XCTAssertEqual(s.moving(.top, to: 0.75), EdgeStripBounds(bottom: 0.15, top: 0.75))
        XCTAssertEqual(s.moving(.top, to: 0.99).top, 0.85)
        // Üst uç alt uca en az yükseklik kadar yaklaşır; alt uç yerinde kalır.
        let near = s.moving(.top, to: 0.2)
        XCTAssertEqual(near.bottom, 0.15)
        XCTAssertEqual(near.top, 0.30, accuracy: 1e-9)
        XCTAssertEqual(s.moving(.bottom, to: 0.05), EdgeStripBounds(bottom: 0.05, top: 0.60))
        XCTAssertEqual(s.moving(.bottom, to: -1).bottom, 0)
        XCTAssertEqual(s.moving(.bottom, to: 0.58).bottom, 0.45, accuracy: 1e-9)
        XCTAssertEqual(s.moving(.bottom, to: 0.58).top, 0.60)
    }

    // MARK: Genişlik tutamacı ve ölçüler

    func testWidthHandle() {
        XCTAssertEqual(EdgeStrip.width(forHandleAt: 0.15, side: .left), 0.15, accuracy: 1e-9)
        XCTAssertEqual(EdgeStrip.width(forHandleAt: 0.85, side: .right), 0.15, accuracy: 1e-9)
        // 0.06…0.20 aralığına sıkıştırılır.
        XCTAssertEqual(EdgeStrip.width(forHandleAt: 0.5, side: .left), 0.20)
        XCTAssertEqual(EdgeStrip.width(forHandleAt: 0.01, side: .left), 0.06)
        XCTAssertEqual(EdgeStrip.width(forHandleAt: 1.2, side: .right), 0.06)
        XCTAssertEqual(EdgeStrip.width(forHandleAt: 0.3, side: .right), 0.20)
        XCTAssertEqual(EdgeStrip.clampedWidth(0.12), 0.12)
        XCTAssertEqual(EdgeStrip.clampedWidth(-1), EdgeSlideRecognizer.edgeWidthRange.lowerBound)
    }

    func testReadout() {
        let r = ZoneReadout(layout: .standard, edgeWidth: 0.12, edgeBounds: .standard)
        XCTAssertEqual([r.left, r.center, r.right], [35, 30, 35])
        XCTAssertEqual([r.rear, r.centerHeight], [40, 60])
        XCTAssertEqual([r.edgeWidth, r.edgeBottom, r.edgeTop], [12, 15, 60])
        let other = ZoneReadout(layout: ZoneLayout(leftEdge: 0.3, rightEdge: 0.72, frontLimit: 0.35, centerTop: 0.8),
                                edgeWidth: 0.07, edgeBounds: EdgeStripBounds(bottom: 0.2, top: 0.75))
        XCTAssertEqual([other.left, other.center, other.right], [30, 42, 28])
        XCTAssertEqual([other.rear, other.centerHeight], [35, 45])
        XCTAssertEqual([other.edgeWidth, other.edgeBottom, other.edgeTop], [7, 20, 75])
    }

    // MARK: Şerit dikdörtgeni

    func testSideOfPoint() {
        let b = EdgeStripBounds.standard
        XCTAssertEqual(EdgeStrip.side(of: p(1, 0.05, 0.4), width: 0.12, bounds: b), .left)
        XCTAssertEqual(EdgeStrip.side(of: p(1, 0.95, 0.2), width: 0.12, bounds: b), .right)
        XCTAssertNil(EdgeStrip.side(of: p(1, 0.05, 0.8), width: 0.12, bounds: b))
        XCTAssertNil(EdgeStrip.side(of: p(1, 0.5, 0.4), width: 0.12, bounds: b))
        XCTAssertEqual(EdgeStrip.side(forX: 0.05, width: 0.12), .left)
        XCTAssertNil(EdgeStrip.side(forX: 0.5, width: 0.12))
    }

    func testExcludingRemovesOnlyEnabledStripTouches() {
        let b = EdgeStripBounds.standard
        let thumb = p(1, 0.05, 0.4)      // sol şeritte
        let index = p(2, 0.5, 0.8)       // önde, ortada
        let rightRest = p(3, 0.95, 0.4)  // sağ şeritte
        let frontEdge = p(4, 0.05, 0.8)  // sol sütun ama şeridin önünde
        let all = [thumb, index, rightRest, frontEdge]
        XCTAssertEqual(EdgeStrip.excluding(points: all, sides: [.left], width: 0.12, bounds: b),
                       [index, rightRest, frontEdge])
        XCTAssertEqual(EdgeStrip.excluding(points: all, sides: [.left, .right], width: 0.12, bounds: b),
                       [index, frontEdge])
        // Kenar kapalıyken süzme yok.
        XCTAssertEqual(EdgeStrip.excluding(points: all, sides: [], width: 0.12, bounds: b), all)
    }

    func testThumbInStripDoesNotMakeTwoFingerPress() {
        // Başparmak açık sol şeritteyken tek parmakla orta bölgeye basmak "iki parmakla bas" olmaz.
        let layout = ZoneLayout.standard
        let points = [p(1, 0.05, 0.4), p(2, 0.5, 0.7)]
        let filtered = EdgeStrip.excluding(points: points, sides: [.left], width: 0.12, bounds: .standard)
        XCTAssertEqual(PressResolver.candidates(fingers: filtered, fnDown: false, layout: layout),
                       [Trigger(kind: .press, fingers: 1, zone: .center)])
        XCTAssertEqual(PressResolver.candidates(fingers: points, fnDown: false, layout: layout),
                       [Trigger(kind: .press, fingers: 2)])
        // Yalnız şeritteki başparmakla basış: aday yok, normal sol tıklama geçer.
        XCTAssertTrue(PressResolver.candidates(fingers: EdgeStrip.excluding(points: [p(1, 0.05, 0.4)], sides: [.left],
                                                                             width: 0.12, bounds: .standard),
                                               fnDown: false, layout: layout).isEmpty)
    }
}

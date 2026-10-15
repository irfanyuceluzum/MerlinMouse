import XCTest
@testable import MerlinCore

final class GestureRecognizerTests: XCTestCase {
    private func pts(_ xs: [Float], y: Float = 0.7, dx: Float = 0, dy: Float = 0) -> [TouchPoint] {
        xs.enumerated().map { TouchPoint(id: Int32($0.offset + 1), x: $0.element + dx, y: y + dy) }
    }

    /// Aynı anda inen parmaklar `duration` sonra kalkar; `move` kadar yukarı kayar.
    private func run(_ r: inout GestureRecognizer, xs: [Float], y: Float = 0.7, start: Double = 0,
                     duration: Double, dx: Float = 0, dy: Float = 0) -> [RecognizedGesture] {
        var out = r.process(TouchFrame(touches: pts(xs, y: y), timestamp: start))
        out += r.process(TouchFrame(touches: pts(xs, y: y, dx: dx / 2, dy: dy / 2), timestamp: start + duration / 2))
        out += r.process(TouchFrame(touches: pts(xs, y: y, dx: dx, dy: dy), timestamp: start + duration * 0.9))
        out += r.process(TouchFrame(touches: [], timestamp: start + duration))
        return out
    }

    func testThreeFingerTap() {
        var r = GestureRecognizer()
        XCTAssertEqual(run(&r, xs: [0.3, 0.5, 0.7], duration: 0.2), [.tap(fingers: 3, zone: .any)])
    }

    func testTooLongNoTap() {
        var r = GestureRecognizer()
        XCTAssertEqual(run(&r, xs: [0.3, 0.5, 0.7], duration: 0.4), [])
    }

    func testTooMuchMoveNoTap() {
        var r = GestureRecognizer()
        XCTAssertEqual(run(&r, xs: [0.3, 0.5, 0.7], duration: 0.2, dy: 0.05), [])
    }

    func testClickCancels() {
        var r = GestureRecognizer()
        _ = r.process(TouchFrame(touches: pts([0.3, 0.5, 0.7]), timestamp: 0))
        r.noteClick()
        XCTAssertEqual(r.process(TouchFrame(touches: [], timestamp: 0.2)), [])
    }

    func testRestingFingerNoTwoFingerTap() {
        var r = GestureRecognizer()
        var out = r.process(TouchFrame(touches: [TouchPoint(id: 1, x: 0.3, y: 0.7)], timestamp: 0))
        out += r.process(TouchFrame(touches: [TouchPoint(id: 1, x: 0.3, y: 0.7)], timestamp: 0.2))
        out += r.process(TouchFrame(touches: [TouchPoint(id: 1, x: 0.3, y: 0.7), TouchPoint(id: 2, x: 0.6, y: 0.7)], timestamp: 0.3))
        out += r.process(TouchFrame(touches: [], timestamp: 0.4))
        XCTAssertEqual(out, [])
    }

    func testThreeFingerSwipeUp() {
        var r = GestureRecognizer()
        XCTAssertEqual(run(&r, xs: [0.3, 0.5, 0.7], y: 0.5, duration: 0.5, dy: 0.2), [.swipe(fingers: 3, direction: .up)])
    }

    func testSwipeDirections() {
        var r = GestureRecognizer()
        XCTAssertEqual(run(&r, xs: [0.3, 0.5, 0.6], y: 0.7, duration: 0.5, dy: -0.2), [.swipe(fingers: 3, direction: .down)])
        XCTAssertEqual(run(&r, xs: [0.3, 0.4, 0.5], start: 10, duration: 0.5, dx: 0.2), [.swipe(fingers: 3, direction: .right)])
        XCTAssertEqual(run(&r, xs: [0.5, 0.6, 0.7], start: 20, duration: 0.5, dx: -0.2), [.swipe(fingers: 3, direction: .left)])
    }

    func testDiagonalNoSwipe() {
        var r = GestureRecognizer()
        XCTAssertEqual(run(&r, xs: [0.3, 0.4, 0.5], y: 0.5, duration: 0.5, dx: 0.15, dy: 0.15), [])
    }

    func testTwoFingerSwipeNone() {
        var r = GestureRecognizer()
        XCTAssertEqual(run(&r, xs: [0.4, 0.6], y: 0.5, duration: 0.5, dy: 0.2), [])
    }

    func testBackZoneIgnored() {
        var r = GestureRecognizer()
        XCTAssertEqual(run(&r, xs: [0.3, 0.5, 0.7], y: 0.2, duration: 0.2), [])
    }

    func testSingleCenterTap() {
        var r = GestureRecognizer()
        XCTAssertEqual(run(&r, xs: [0.5], duration: 0.1), [.tap(fingers: 1, zone: .center)])
    }

    func testDoubleTap() {
        var r = GestureRecognizer()
        r.wantsDoubleTap = { _, _ in true }
        var out = run(&r, xs: [0.5], start: 0, duration: 0.1)
        XCTAssertEqual(out, [])
        XCTAssertEqual(r.pendingDeadline, 0.1 + 0.35)
        out = run(&r, xs: [0.5], start: 0.3, duration: 0.1)
        XCTAssertEqual(out, [.doubleTap(fingers: 1, zone: .center)])
        XCTAssertNil(r.pendingDeadline)
    }

    func testSingleTapFlushed() {
        var r = GestureRecognizer()
        r.wantsDoubleTap = { _, _ in true }
        XCTAssertEqual(run(&r, xs: [0.5], duration: 0.1), [])
        let d = try! XCTUnwrap(r.pendingDeadline)
        XCTAssertEqual(r.flush(now: d - 0.1), [])
        XCTAssertEqual(r.flush(now: d), [.tap(fingers: 1, zone: .center)])
        XCTAssertNil(r.pendingDeadline)
    }

    func testTapImmediateWhenNoDoubleWanted() {
        var r = GestureRecognizer()
        XCTAssertEqual(run(&r, xs: [0.5], duration: 0.1), [.tap(fingers: 1, zone: .center)])
        XCTAssertNil(r.pendingDeadline)
    }

    // MARK: Arka (logo) dokunma

    private func f(_ touches: [TouchPoint], _ t: Double) -> TouchFrame { TouchFrame(touches: touches, timestamp: t) }
    private func rearPt(_ id: Int32 = 1, x: Float = 0.5, y: Float = 0.2) -> TouchPoint { TouchPoint(id: id, x: x, y: y) }

    func testRearTap() {
        var r = GestureRecognizer()
        XCTAssertEqual(run(&r, xs: [0.5], y: 0.2, duration: 0.1), [.tap(fingers: 1, zone: .rear)])
    }

    func testRearTapIgnoredWhenClicked() {
        var r = GestureRecognizer()
        var out = r.process(f([rearPt()], 0))
        r.noteClick()
        out += r.process(f([], 0.1))
        XCTAssertEqual(out, [])
    }

    func testRearPalmRestingProducesNothing() {
        var r = GestureRecognizer()
        XCTAssertEqual(run(&r, xs: [0.5], y: 0.2, duration: 0.6), [])
        XCTAssertEqual(run(&r, xs: [0.5], y: 0.2, start: 5, duration: 3), [])
    }

    func testRearMovedTooMuch() {
        var r = GestureRecognizer()
        XCTAssertEqual(run(&r, xs: [0.5], y: 0.2, duration: 0.2, dx: 0.1), [])
    }

    func testRearNotProducedWithFrontFingerPresent() {
        var r = GestureRecognizer()
        // Ön parmak önce iner, sonra arkaya ikinci parmak.
        var out = r.process(f([TouchPoint(id: 1, x: 0.2, y: 0.7)], 0))
        out += r.process(f([TouchPoint(id: 1, x: 0.2, y: 0.7), rearPt(2)], 0.05))
        out += r.process(f([TouchPoint(id: 1, x: 0.2, y: 0.7)], 0.1))
        out += r.process(f([], 0.2))
        XCTAssertFalse(out.contains(.tap(fingers: 1, zone: .rear)))
        // Arka parmak önce, ön parmak sonra.
        var r2 = GestureRecognizer()
        var o2 = r2.process(f([rearPt()], 0))
        o2 += r2.process(f([rearPt(), TouchPoint(id: 2, x: 0.5, y: 0.7)], 0.05))
        o2 += r2.process(f([], 0.15))
        XCTAssertFalse(o2.contains(.tap(fingers: 1, zone: .rear)))
    }

    func testRearNotProducedWhenSecondFingerAdded() {
        var r = GestureRecognizer()
        var out = r.process(f([rearPt()], 0))
        out += r.process(f([rearPt(), rearPt(2, x: 0.7)], 0.05))
        out += r.process(f([rearPt()], 0.1))
        out += r.process(f([], 0.15))
        XCTAssertEqual(out, [])
    }

    func testRearNotProducedWhenLandingOnTopOfRestingFinger() {
        var r = GestureRecognizer()
        // Ön parmak kalkarken arkada kalan parmak yeni oturum sayılmaz.
        var out = r.process(f([TouchPoint(id: 1, x: 0.2, y: 0.7), rearPt(2)], 0))
        out += r.process(f([rearPt(2)], 0.1))
        out += r.process(f([], 0.2))
        XCTAssertFalse(out.contains(.tap(fingers: 1, zone: .rear)))
    }

    func testRearDoubleTap() {
        var r = GestureRecognizer()
        r.wantsDoubleTap = { fingers, zone in fingers == 1 && zone == .rear }
        var out = run(&r, xs: [0.5], y: 0.2, start: 0, duration: 0.1)
        XCTAssertEqual(out, [])
        out = run(&r, xs: [0.5], y: 0.2, start: 0.3, duration: 0.1)
        XCTAssertEqual(out, [.doubleTap(fingers: 1, zone: .rear)])
    }

    func testRearSingleTapFlushedWhenDoubleWanted() {
        var r = GestureRecognizer()
        r.wantsDoubleTap = { _, zone in zone == .rear }
        XCTAssertEqual(run(&r, xs: [0.5], y: 0.2, duration: 0.1), [])
        let d = try! XCTUnwrap(r.pendingDeadline)
        XCTAssertEqual(r.flush(now: d), [.tap(fingers: 1, zone: .rear)])
    }

    func testFrontOneFingerStillUsesLayout() {
        var r = GestureRecognizer()
        r.layout = ZoneLayout(leftEdge: 0.2, rightEdge: 0.5, frontLimit: 0.4)
        XCTAssertEqual(run(&r, xs: [0.6], duration: 0.1), [.tap(fingers: 1, zone: .right)])
        XCTAssertEqual(run(&r, xs: [0.1], start: 1, duration: 0.1), [.tap(fingers: 1, zone: .left)])
    }
}

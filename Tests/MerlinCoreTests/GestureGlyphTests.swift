import XCTest
@testable import MerlinCore

final class GestureGlyphTests: XCTestCase {
    private func glyph(_ kind: GestureKind, fingers: Int = 1, zone: Zone = .any,
                       direction: SwipeDirection = .up, modifier: PressModifier = .none) -> GestureGlyph {
        GestureGlyph(trigger: Trigger(kind: kind, fingers: fingers, zone: zone, direction: direction, modifier: modifier))
    }

    private func points(_ g: GestureGlyph) -> [[Double]] { g.dots.map { [$0.x, $0.y] } }

    // MARK: Basma

    func testPressOneFingerCenter() {
        let g = glyph(.press, zone: .center)
        XCTAssertEqual(g.dots, [GlyphDot(x: 14, y: 12, hollow: false)])
        XCTAssertEqual(g.rings, [GlyphRing(x: 14, y: 12, radius: 6)])
        XCTAssertTrue(g.labels.isEmpty)
        XCTAssertFalse(g.rear)
    }

    func testPressOneFingerRight() {
        let g = glyph(.press, zone: .right)
        XCTAssertEqual(g.dots, [GlyphDot(x: 20, y: 11, hollow: false)])
        XCTAssertEqual(g.rings, [GlyphRing(x: 20, y: 11, radius: 6)])
    }

    func testPressAnyAndLeftDrawLikeCenter() {
        XCTAssertEqual(glyph(.press, zone: .any), glyph(.press, zone: .center))
        XCTAssertEqual(glyph(.press, zone: .left), glyph(.press, zone: .center))
    }

    func testPressTwoFingers() {
        let g = glyph(.press, fingers: 2)
        XCTAssertEqual(points(g), [[10, 12], [18, 12]])
        XCTAssertTrue(g.dots.allSatisfy { !$0.hollow })
        XCTAssertEqual(g.rings.map(\.radius), [5, 5])
    }

    func testPressThreeAndMoreFingers() {
        for n in [3, 4, 5] {
            let g = glyph(.press, fingers: n)
            XCTAssertEqual(points(g), [[8, 12], [14, 10], [20, 12]], "\(n) parmak")
            XCTAssertEqual(g.rings.count, 3)
            XCTAssertTrue(g.rings.allSatisfy { $0.radius == 5 })
        }
    }

    func testPressWithModifierShowsKeyLabel() {
        let expected: [PressModifier: String] = [.fn: "fn", .option: "⌥", .command: "⌘", .shift: "⇧"]
        for (m, text) in expected {
            let g = glyph(.press, fingers: 0, modifier: m)
            XCTAssertEqual(g.dots, [GlyphDot(x: 14, y: 11, hollow: false)])
            XCTAssertEqual(g.rings, [GlyphRing(x: 14, y: 11, radius: 6)])
            XCTAssertEqual(g.labels, [GlyphLabel(x: 14, y: 24, text: text, size: 9)])
        }
    }

    func testHoldDrawsLikePress() {
        XCTAssertEqual(glyph(.hold, fingers: 2), glyph(.press, fingers: 2))
        XCTAssertEqual(glyph(.hold, zone: .right), glyph(.press, zone: .right))
        XCTAssertEqual(glyph(.hold, fingers: 0, modifier: .fn), glyph(.press, fingers: 0, modifier: .fn))
    }

    // MARK: Dokunma

    func testTapRear() {
        let g = glyph(.tap, zone: .rear)
        XCTAssertTrue(g.rear)
        XCTAssertEqual(g.dots, [GlyphDot(x: 14, y: 28, hollow: true)])
        XCTAssertTrue(g.rings.isEmpty)
        XCTAssertTrue(g.labels.isEmpty)
    }

    func testTapMultiFingerHollow() {
        let two = glyph(.tap, fingers: 2)
        XCTAssertEqual(points(two), [[10, 12], [18, 12]])
        XCTAssertTrue(two.dots.allSatisfy(\.hollow))
        XCTAssertTrue(two.rings.isEmpty)
        let three = glyph(.tap, fingers: 3)
        XCTAssertEqual(three.dots.count, 3)
        XCTAssertTrue(three.dots.allSatisfy(\.hollow))
        XCTAssertFalse(three.rear)
    }

    func testDoubleTapRear() {
        let g = glyph(.doubleTap, zone: .rear)
        XCTAssertTrue(g.rear)
        XCTAssertEqual(g.dots, [GlyphDot(x: 14, y: 28, hollow: true)])
        XCTAssertEqual(g.rings, [GlyphRing(x: 14, y: 28, radius: 5)])
        XCTAssertEqual(g.labels, [GlyphLabel(x: 14, y: 13, text: "2×", size: 9)])
    }

    func testDoubleTapOneFingerFollowsZone() {
        let expected: [Zone: [Double]] = [.any: [14, 12], .center: [14, 12], .left: [8, 12], .right: [20, 11]]
        for (z, p) in expected {
            let g = glyph(.doubleTap, zone: z)
            XCTAssertEqual(points(g), [p], "\(z)")
            XCTAssertTrue(g.dots.allSatisfy(\.hollow))
            XCTAssertTrue(g.rings.isEmpty)
            XCTAssertEqual(g.labels, [GlyphLabel(x: 14, y: 24, text: "2×", size: 9)])
            XCTAssertFalse(g.rear)
        }
    }

    func testDoubleTapTwoAndThreeFingers() {
        let two = glyph(.doubleTap, fingers: 2)
        XCTAssertEqual(points(two), [[10, 12], [18, 12]])
        XCTAssertTrue(two.dots.allSatisfy(\.hollow))
        XCTAssertEqual(two.rings.map(\.radius), [5, 5])
        XCTAssertEqual(two.labels.map(\.text), ["2×"])
        let three = glyph(.doubleTap, fingers: 3)
        XCTAssertEqual(three.dots.count, 3)
        XCTAssertTrue(three.dots.allSatisfy(\.hollow))
        XCTAssertTrue(three.rings.isEmpty)
        XCTAssertEqual(three.labels.map(\.text), ["2×"])
    }

    // MARK: Kaydırma ve çimdikleme

    func testSwipeUpShiftsDotsDown() {
        let g = glyph(.swipe, fingers: 3, direction: .up)
        XCTAssertEqual(points(g), [[8, 20], [14, 18], [20, 20]])
        XCTAssertTrue(g.dots.allSatisfy { !$0.hollow })
        XCTAssertEqual(g.labels.map(\.text), ["↑"])
        XCTAssertEqual(g.labels.first?.y, 9)
        XCTAssertTrue(g.rings.isEmpty)
    }

    func testSwipeOtherDirections() {
        let expected: [SwipeDirection: String] = [.down: "↓", .left: "←", .right: "→"]
        for (d, arrow) in expected {
            let g = glyph(.swipe, fingers: 4, direction: d)
            XCTAssertEqual(points(g), [[8, 12], [14, 10], [20, 12]])
            XCTAssertEqual(g.labels.count, 1)
            XCTAssertEqual(g.labels.first?.text, arrow)
            XCTAssertEqual(g.labels.first?.y, 23)
        }
    }

    func testPinch() {
        let g = glyph(.pinch, fingers: 2)
        XCTAssertEqual(g.dots, [GlyphDot(x: 9, y: 14, hollow: false), GlyphDot(x: 19, y: 14, hollow: false)])
        XCTAssertEqual(g.labels.map(\.text), ["↔"])
        XCTAssertEqual(g.labels.first?.y, 25)
        XCTAssertTrue(g.rings.isEmpty)
        XCTAssertFalse(g.rear)
    }

    func testEdgeSlide() {
        let left = glyph(.edgeSlide, zone: .leftEdge)
        XCTAssertEqual(left.dots, [GlyphDot(x: 7, y: 16, hollow: false)])
        XCTAssertEqual(left.labels, [GlyphLabel(x: 15, y: 16, text: "↕", size: 10)])
        XCTAssertEqual(left.edge, .left)
        XCTAssertTrue(left.rings.isEmpty)
        XCTAssertFalse(left.rear)
        let right = glyph(.edgeSlide, zone: .rightEdge)
        XCTAssertEqual(right.dots, [GlyphDot(x: 21, y: 16, hollow: false)])
        XCTAssertEqual(right.labels, [GlyphLabel(x: 13, y: 16, text: "↕", size: 10)])
        XCTAssertEqual(right.edge, .right)
        // Kenar dışı bölge sol kenara çekilir; diğer türlerde şerit yok.
        XCTAssertEqual(glyph(.edgeSlide, fingers: 3, zone: .center, modifier: .fn), left)
        XCTAssertNil(glyph(.press, fingers: 2).edge)
        XCTAssertEqual(glyph(.doubleTap, zone: .leftEdge), glyph(.doubleTap, zone: .any))
    }

    // MARK: Normalleştirme

    func testPinchIgnoresZoneFingersAndModifier() {
        let messy = glyph(.pinch, fingers: 4, zone: .rear, direction: .left, modifier: .command)
        XCTAssertEqual(messy, glyph(.pinch, fingers: 2))
        XCTAssertFalse(messy.rear)
    }

    func testMultiFingerIgnoresZone() {
        XCTAssertEqual(glyph(.tap, fingers: 2, zone: .rear), glyph(.tap, fingers: 2))
        XCTAssertFalse(glyph(.doubleTap, fingers: 3, zone: .rear).rear)
    }

    func testModifierIgnoredOutsidePress() {
        XCTAssertEqual(glyph(.tap, zone: .rear, modifier: .fn), glyph(.tap, zone: .rear))
    }

    func testModifierOverridesFingersAndZone() {
        XCTAssertEqual(glyph(.press, fingers: 3, zone: .right, modifier: .option),
                       glyph(.press, fingers: 0, modifier: .option))
    }

    func testDirectionIgnoredOutsideSwipe() {
        XCTAssertEqual(glyph(.press, fingers: 2, direction: .left), glyph(.press, fingers: 2))
    }

    func testAllDotsInsideBox() {
        var triggers: [Trigger] = []
        for k in GestureKind.allCases {
            for f in 0...5 {
                for z in Zone.allCases {
                    for d in SwipeDirection.allCases {
                        for m in PressModifier.allCases {
                            triggers.append(Trigger(kind: k, fingers: f, zone: z, direction: d, modifier: m))
                        }
                    }
                }
            }
        }
        for t in triggers {
            let g = GestureGlyph(trigger: t)
            XCTAssertFalse(g.dots.isEmpty, "\(t)")
            for d in g.dots {
                XCTAssertTrue(d.x - 3 >= GestureGlyph.bodyX && d.x + 3 <= GestureGlyph.bodyX + GestureGlyph.bodyWidth, "\(t)")
                XCTAssertTrue(d.y - 3 >= GestureGlyph.bodyY && d.y + 3 <= GestureGlyph.bodyY + GestureGlyph.bodyHeight, "\(t)")
            }
        }
    }
}

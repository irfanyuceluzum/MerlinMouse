import XCTest
@testable import MerlinCore

/// Kart 34: trackpad simgesi, trackpad hazır hareketleri ve serbest hareket listesi.
final class TrackpadInterfaceTests: XCTestCase {
    // MARK: Simge

    func testTrackpadBodyGeometry() {
        XCTAssertEqual(GestureGlyph.trackpadBodyWidth, 26)
        XCTAssertEqual(GestureGlyph.trackpadBodyHeight, 18)
        XCTAssertEqual(GestureGlyph.trackpadBodyRadius, 4)
        XCTAssertEqual(GestureGlyph.trackpadBodyX, 1)
        XCTAssertEqual(GestureGlyph.trackpadBodyY, 9)
        XCTAssertEqual(GestureGlyph.trackpadY(0), 11)
        XCTAssertEqual(GestureGlyph.trackpadY(12), 17)
        XCTAssertEqual(GestureGlyph.trackpadY(24), 23)
    }

    func testTrackpadGlyphCompressesIntoBody() {
        let triggers = [
            Trigger(kind: .tap, fingers: 3), Trigger(kind: .press, fingers: 3), Trigger(kind: .doubleTap, fingers: 3),
            Trigger(kind: .tap, fingers: 4), Trigger(kind: .press, fingers: 4), Trigger(kind: .doubleTap, fingers: 4),
        ]
        let top = GestureGlyph.trackpadBodyY, bottom = top + GestureGlyph.trackpadBodyHeight
        for t in triggers {
            let mouse = GestureGlyph(trigger: t)
            let pad = GestureGlyph(trigger: t, device: .trackpad)
            XCTAssertEqual(pad.dots, mouse.dots.map { GlyphDot(x: $0.x, y: 11 + $0.y * 0.5, hollow: $0.hollow) }, t.title)
            XCTAssertEqual(pad.rings, mouse.rings.map { GlyphRing(x: $0.x, y: 11 + $0.y * 0.5, radius: $0.radius) }, t.title)
            XCTAssertEqual(pad.labels.map(\.text), mouse.labels.map(\.text), t.title)
            XCTAssertTrue(pad.dots.allSatisfy { $0.y >= top && $0.y <= bottom }, t.title)
            XCTAssertTrue(pad.labels.allSatisfy { $0.y >= top && $0.y <= bottom }, t.title)
        }
        // Trackpad'de arka bölge ve kenar şeridi yok; fare tarifi değişmez.
        let rear = Trigger(kind: .tap, fingers: 1, zone: .rear)
        XCTAssertTrue(GestureGlyph(trigger: rear).rear)
        XCTAssertFalse(GestureGlyph(trigger: rear, device: .trackpad).rear)
        let edge = Trigger(kind: .edgeSlide, zone: .leftEdge)
        XCTAssertNil(GestureGlyph(trigger: edge, device: .trackpad).edge)
        XCTAssertEqual(GestureGlyph(trigger: edge, device: .magicMouse), GestureGlyph(trigger: edge))
    }

    // MARK: Hazır hareketler

    func testTrackpadPresets() {
        let p = GesturePresets.presets(for: .trackpad)
        XCTAssertEqual(p.map(\.title), ["Üç parmakla dokun", "Üç parmakla bas", "Üç parmakla çift dokun",
                                        "Dört parmakla dokun", "Dört parmakla bas"])
        XCTAssertEqual(p.map(\.trigger), [
            Trigger(kind: .tap, fingers: 3), Trigger(kind: .press, fingers: 3), Trigger(kind: .doubleTap, fingers: 3),
            Trigger(kind: .tap, fingers: 4), Trigger(kind: .press, fingers: 4),
        ].map(\.normalized))
        for preset in p {
            // Trackpad seçenekleriyle geçerli ve başlık tetiğin kendi başlığı.
            XCTAssertEqual(TriggerOptions.sanitize(preset.trigger, device: .trackpad), preset.trigger, preset.title)
            XCTAssertEqual(preset.trigger.title, preset.title)
            let probe = GestureBinding(trigger: preset.trigger, action: .middleClick, device: .trackpad)
            let conflicts = ConflictChecker.check(probe, among: [], env: ConflictEnvironment())
            XCTAssertFalse(conflicts.contains { $0.level.blocksSave }, preset.title)
        }
        // Fare hazırları aynen.
        XCTAssertEqual(GesturePresets.presets(for: .magicMouse), GesturePresets.all)
        XCTAssertEqual(GesturePresets.all.count, 14)
    }

    func testTrackpadFreeGestures() {
        XCTAssertEqual(TrackpadGestureCatalog.freeGestures,
                       ["Üç parmakla dokunma", "Üç parmakla basma", "Dört parmakla dokunma"])
    }
}

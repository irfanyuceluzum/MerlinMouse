import XCTest
@testable import MerlinCore

/// Kart 36: trackpad köşelerine basma.
final class TrackpadCornerTests: XCTestCase {
    private let env = ConflictEnvironment()
    private let layout = TrackpadCornerLayout.standard

    private func press(_ zone: Zone) -> Trigger { Trigger(kind: .press, fingers: 1, zone: zone) }
    private func padBinding(_ t: Trigger, enabled: Bool = true) -> GestureBinding {
        GestureBinding(trigger: t, action: .middleClick, enabled: enabled, device: .trackpad)
    }

    // MARK: Model

    func testZoneCorners() throws {
        XCTAssertEqual(Zone.corners, [.cornerTopLeft, .cornerTopRight, .cornerBottomLeft, .cornerBottomRight])
        XCTAssertEqual(Zone.corners.map(\.rawValue), ["cornerTopLeft", "cornerTopRight", "cornerBottomLeft", "cornerBottomRight"])
        XCTAssertEqual(Zone.corners.map(\.displayName), ["Sol üst köşe", "Sağ üst köşe", "Sol alt köşe", "Sağ alt köşe"])
        XCTAssertTrue(Zone.corners.allSatisfy(\.isCorner))
        XCTAssertFalse(Zone.allCases.filter { !Zone.corners.contains($0) }.contains { $0.isCorner })
        XCTAssertEqual(Zone.corners.map { press($0).title },
                       ["Sol üst köşeye bas", "Sağ üst köşeye bas", "Sol alt köşeye bas", "Sağ alt köşeye bas"])
        // Kodlama ham adla, geri okunur.
        let data = try JSONEncoder().encode(press(.cornerBottomLeft))
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"cornerBottomLeft\""))
        XCTAssertEqual(try JSONDecoder().decode(Trigger.self, from: data), press(.cornerBottomLeft))
    }

    func testNormalizationKeepsCornerOnlyForOneFingerPress() {
        XCTAssertEqual(press(.cornerTopRight).normalized.zone, .cornerTopRight)
        XCTAssertEqual(Trigger(kind: .hold, fingers: 1, zone: .cornerTopRight).normalized.zone, .cornerTopRight)
        XCTAssertEqual(Trigger(kind: .tap, fingers: 1, zone: .cornerTopRight).normalized.zone, .any)
        XCTAssertEqual(Trigger(kind: .doubleTap, fingers: 1, zone: .cornerTopRight).normalized.zone, .any)
        XCTAssertEqual(Trigger(kind: .press, fingers: 3, zone: .cornerTopRight).normalized.zone, .any)
        XCTAssertEqual(Trigger(kind: .press, fingers: 1, zone: .cornerTopRight, modifier: .fn).normalized.zone, .any)
        XCTAssertEqual(Trigger(kind: .edgeSlide, zone: .cornerTopRight).normalized.zone, .leftEdge)
    }

    func testMouseNeverGetsCorners() {
        // Fare sınıflaması köşe döndürmez.
        for xi in 0...20 {
            for yi in 0...20 {
                let z = Zone.classify(x: Float(xi) / 20, y: Float(yi) / 20, layout: .standard)
                XCTAssertFalse(z.isCorner)
            }
        }
        // Fare seçenekleri ve düzeltme köşe vermez.
        for k in GestureKind.allCases {
            for f in 0...4 {
                for m in PressModifier.allCases {
                    XCTAssertFalse(TriggerOptions.zoneChoices(kind: k, fingers: f, modifier: m).contains { $0.isCorner })
                }
                for z in Zone.corners {
                    XCTAssertFalse(TriggerOptions.sanitize(Trigger(kind: k, fingers: f, zone: z)).zone.isCorner, "\(k) \(f) \(z)")
                }
            }
        }
        // Fare atamasında köşe desteklenmez.
        let mouse = GestureBinding(trigger: press(.cornerBottomLeft), action: .middleClick)
        XCTAssertTrue(ConflictChecker.check(mouse, among: [], env: env).contains { $0.level == .unsupported })
    }

    // MARK: Köşe düzeni

    func testCornerLayoutClamp() {
        XCTAssertEqual(TrackpadCornerLayout.standard, TrackpadCornerLayout(width: 0.18, height: 0.22))
        XCTAssertEqual(TrackpadCornerLayout.range, 0.08...0.35)
        XCTAssertEqual(TrackpadCornerLayout(width: 0.01, height: 0.9).clamped(), TrackpadCornerLayout(width: 0.08, height: 0.35))
        XCTAssertEqual(TrackpadCornerLayout(width: .nan, height: .infinity).clamped(), .standard)
        XCTAssertEqual(TrackpadCornerLayout(width: 0.2, height: 0.3).clamped(), TrackpadCornerLayout(width: 0.2, height: 0.3))
    }

    /// y 0 kullanıcıya yakın kenardır (alt): MT'nin normalleştirilmiş konumu Magic Mouse'ta da y 0 = avuç / arka verir.
    func testCornerClassifyUsesBottomAtYZero() {
        XCTAssertEqual(layout.classify(x: 0.05, y: 0.05), .cornerBottomLeft)
        XCTAssertEqual(layout.classify(x: 0.95, y: 0.05), .cornerBottomRight)
        XCTAssertEqual(layout.classify(x: 0.05, y: 0.95), .cornerTopLeft)
        XCTAssertEqual(layout.classify(x: 0.95, y: 0.95), .cornerTopRight)
        XCTAssertNil(layout.classify(x: 0.5, y: 0.5))
        // Yalnız bir eksende kenarda olmak köşe değildir.
        XCTAssertNil(layout.classify(x: 0.05, y: 0.5))
        XCTAssertNil(layout.classify(x: 0.5, y: 0.05))
        // Sınır: genişlik / yükseklik dışı.
        XCTAssertNil(layout.classify(x: 0.19, y: 0.05))
        XCTAssertNil(layout.classify(x: 0.05, y: 0.23))
        // Ölçü değişince sınır da değişir.
        XCTAssertEqual(TrackpadCornerLayout(width: 0.3, height: 0.3).classify(x: 0.25, y: 0.25), .cornerBottomLeft)
    }

    // MARK: Basma adayları

    func testOneFingerInCornerIsCandidate() {
        let points: [(Float, Float, Zone)] = [(0.05, 0.05, .cornerBottomLeft), (0.95, 0.05, .cornerBottomRight),
                                              (0.05, 0.95, .cornerTopLeft), (0.95, 0.95, .cornerTopRight)]
        for (x, y, z) in points {
            let c = PressResolver.trackpadCandidates(fingers: [TouchPoint(id: 1, x: x, y: y)], fnDown: false, corners: layout)
            XCTAssertEqual(c, [press(z)])
        }
        // Çok parmakta köşe aranmaz.
        let two = [TouchPoint(id: 1, x: 0.05, y: 0.05), TouchPoint(id: 2, x: 0.5, y: 0.5)]
        XCTAssertEqual(PressResolver.trackpadCandidates(fingers: two, fnDown: false, corners: layout),
                       [Trigger(kind: .press, fingers: 2)])
    }

    /// Köşe dışındaki tek parmak tıklaması asla dönüşmez: aday yok, bütün trackpad atamaları açıkken bile eşleşme yok.
    func testOneFingerOutsideCornersNeverConverts() {
        var all: [GestureBinding] = Zone.corners.map { padBinding(press($0)) }
        for k in [GestureKind.press, .tap, .doubleTap] {
            for f in [3, 4] { all.append(padBinding(Trigger(kind: k, fingers: f))) }
        }
        let idx = BindingIndex(bindings: all)
        for xi in 0...40 {
            for yi in 0...40 {
                let x = Float(xi) / 40, y = Float(yi) / 40
                guard layout.classify(x: x, y: y) == nil else { continue }
                let c = PressResolver.trackpadCandidates(fingers: [TouchPoint(id: 1, x: x, y: y)], fnDown: false,
                                                         corners: layout)
                XCTAssertEqual(c, [], "\(x),\(y)")
                XCTAssertTrue(c.allSatisfy { idx.match($0, bundleID: nil, device: .trackpad) == nil })
            }
        }
        // Köşesiz tek parmak trackpad ataması ayrılmıştır.
        for z in [Zone.any, .center, .right, .left] {
            XCTAssertTrue(ConflictChecker.check(padBinding(press(z)), among: [], env: env).contains { $0.level == .reserved }, "\(z)")
        }
    }

    // MARK: Çakışmalar

    private func levels(_ t: Trigger, _ e: ConflictEnvironment) -> [ConflictLevel] {
        ConflictChecker.check(padBinding(t), among: [], env: e).map(\.level)
    }

    func testCornerSecondaryClickConflict() {
        XCTAssertNil(env.secondaryClickCorner)
        let bottomLeft = ConflictEnvironment(trackpadCornerSecondaryClick: 1)
        let bottomRight = ConflictEnvironment(trackpadCornerSecondaryClick: 2)
        XCTAssertEqual(bottomLeft.secondaryClickCorner, .cornerBottomLeft)
        XCTAssertEqual(bottomRight.secondaryClickCorner, .cornerBottomRight)
        XCTAssertNil(ConflictEnvironment(trackpadCornerSecondaryClick: 7).secondaryClickCorner)

        XCTAssertEqual(levels(press(.cornerBottomLeft), bottomLeft), [.macOS])
        XCTAssertEqual(levels(press(.cornerBottomRight), bottomLeft), [])
        XCTAssertEqual(levels(press(.cornerBottomRight), bottomRight), [.macOS])
        XCTAssertEqual(levels(press(.cornerBottomLeft), bottomRight), [])
        for z in [Zone.cornerTopLeft, .cornerTopRight] {
            XCTAssertEqual(levels(press(z), bottomLeft), [])
            XCTAssertEqual(levels(press(z), bottomRight), [])
        }
        XCTAssertEqual(ConflictChecker.check(padBinding(press(.cornerBottomRight)), among: [], env: bottomRight).first?.detail,
                       "Bu köşeye tıklamak macOS'ta ikincil tıklama olarak ayarlı.")
        for z in Zone.corners { XCTAssertEqual(levels(press(z), env), []) }
    }

    func testTapToClickCautionAndOneFingerTapReserved() {
        let tapClick = ConflictEnvironment(trackpadTapToClick: true)
        XCTAssertEqual(levels(press(.cornerTopLeft), tapClick), [.caution])
        XCTAssertTrue(levels(Trigger(kind: .tap, fingers: 1), env).contains(.reserved))
        XCTAssertTrue(levels(Trigger(kind: .doubleTap, fingers: 1), env).contains(.reserved))
        // Fare kuralları değişmedi: farede tek parmak çift dokunma serbest, sol bölge ayrılmış.
        let mouseDouble = GestureBinding(trigger: Trigger(kind: .doubleTap, fingers: 1), action: .back)
        XCTAssertFalse(ConflictChecker.check(mouseDouble, among: [], env: env).contains { $0.level == .reserved })
        let mouseLeft = GestureBinding(trigger: Trigger(kind: .press, fingers: 1, zone: .left), action: .back)
        XCTAssertEqual(ConflictChecker.check(mouseLeft, among: [], env: env).first?.title, "Normal sol tıklama")
    }

    // MARK: Simge ve hazırlar

    func testCornerGlyph() {
        let expected: [(Zone, Double, Double)] = [(.cornerBottomLeft, 6, 24), (.cornerBottomRight, 22, 24),
                                                  (.cornerTopLeft, 6, 4), (.cornerTopRight, 22, 4)]
        for (z, x, y) in expected {
            let g = GestureGlyph(trigger: press(z))
            XCTAssertEqual(g.dots, [GlyphDot(x: x, y: y, hollow: false)], "\(z)")
            XCTAssertEqual(g.rings, [GlyphRing(x: x, y: y, radius: 5)], "\(z)")
            let pad = GestureGlyph(trigger: press(z), device: .trackpad)
            XCTAssertEqual(pad.dots, [GlyphDot(x: x, y: GestureGlyph.trackpadY(y), hollow: false)], "\(z)")
            // Gövdenin içinde kalır.
            let top = GestureGlyph.trackpadBodyY, bottom = top + GestureGlyph.trackpadBodyHeight
            XCTAssertTrue(pad.dots.allSatisfy { $0.y - 3 >= top && $0.y + 3 <= bottom }, "\(z)")
        }
    }

    func testCornerPresetsAndOptions() {
        let corners = GesturePresets.trackpad.suffix(4)
        XCTAssertEqual(corners.map(\.trigger), Zone.corners.map { press($0) })
        XCTAssertEqual(TriggerOptions.sanitize(press(.cornerBottomRight), device: .trackpad), press(.cornerBottomRight))
        // Trackpad'de tek parmak dokunma yok; 3'e çekilir.
        XCTAssertEqual(TriggerOptions.sanitize(Trigger(kind: .tap, fingers: 1), device: .trackpad), Trigger(kind: .tap, fingers: 3))
        XCTAssertEqual(TriggerOptions.sanitize(Trigger(kind: .doubleTap, fingers: 1), device: .trackpad),
                       Trigger(kind: .doubleTap, fingers: 3))
    }
}

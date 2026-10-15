import XCTest
@testable import MerlinCore

final class PinchRecognizerTests: XCTestCase {
    private var time = 0.0

    /// Ön bölgede (y = 0.7) yatay iki parmak; merkez `cx`, aralık `gap`.
    private func two(gap: Float, cx: Float = 0.5, y: Float = 0.7) -> [TouchPoint] {
        [TouchPoint(id: 1, x: cx - gap / 2, y: y), TouchPoint(id: 2, x: cx + gap / 2, y: y)]
    }

    /// Tüm olaylar (`.moved` dahil).
    private func feedAll(_ r: inout PinchRecognizer, _ touches: [TouchPoint]) -> [PinchEvent] {
        time += 0.01
        return r.process(TouchFrame(touches: touches, timestamp: time))
    }

    /// `.moved` dışındaki olaylar (başlangıç, adım, bitiş).
    private func feed(_ r: inout PinchRecognizer, _ touches: [TouchPoint]) -> [PinchEvent] {
        feedAll(&r, touches).filter { if case .moved = $0 { return false } else { return true } }
    }

    private func moves(_ events: [PinchEvent]) -> [Float] {
        events.compactMap { if case .moved(let d) = $0 { return d } else { return nil } }
    }

    /// 0.2 aralıkla başlar, 0.27'de etkinleşir (çapa 0.27).
    private func begun() -> PinchRecognizer {
        var r = PinchRecognizer()
        XCTAssertEqual(feed(&r, two(gap: 0.2)), [])
        XCTAssertEqual(feed(&r, two(gap: 0.27)), [.began])
        XCTAssertTrue(r.isActive)
        return r
    }

    func testBeginThreshold() {
        var r = PinchRecognizer()
        XCTAssertEqual(feed(&r, two(gap: 0.2)), [])
        XCTAssertEqual(feed(&r, two(gap: 0.23)), [])
        XCTAssertFalse(r.isActive)
        XCTAssertEqual(feed(&r, two(gap: 0.27)), [.began])
        XCTAssertTrue(r.isActive)
    }

    func testOpenAndCloseSteps() {
        var r = begun()
        XCTAssertEqual(feed(&r, two(gap: 0.285)), [])
        XCTAssertEqual(feed(&r, two(gap: 0.3)), [.step(1)])
        XCTAssertEqual(feed(&r, two(gap: 0.26)), [.step(-1)])
    }

    func testLargeJumpProducesMultipleSteps() {
        var r = begun()
        XCTAssertEqual(feed(&r, two(gap: 0.35)), [.step(1), .step(1), .step(1)])
        XCTAssertEqual(feed(&r, two(gap: 0.29)), [.step(-1), .step(-1)])
    }

    func testCustomStep() {
        var r = begun()
        r.step = 0.012
        XCTAssertEqual(feed(&r, two(gap: 0.3)), [.step(1), .step(1)])
    }

    func testParallelSwipeIsNotPinch() {
        var r = PinchRecognizer()
        _ = feed(&r, two(gap: 0.2, cx: 0.4))
        // Mesafe sabit, merkez kayıyor.
        for cx: Float in [0.45, 0.5, 0.55, 0.6] {
            XCTAssertEqual(feed(&r, two(gap: 0.2, cx: cx)), [])
        }
        // Kayma büyükken mesafedeki küçük değişim de başlatmaz.
        XCTAssertEqual(feed(&r, two(gap: 0.26, cx: 0.65)), [])
        XCTAssertFalse(r.isActive)
    }

    func testThirdFingerCancelsUntilAllLift() {
        var r = begun()
        var three = two(gap: 0.3)
        three.append(TouchPoint(id: 3, x: 0.5, y: 0.9))
        XCTAssertEqual(feed(&r, three), [.ended])
        XCTAssertFalse(r.isActive)
        // Üçüncü parmak kalksa da yeni çimdikleme başlamaz.
        XCTAssertEqual(feed(&r, two(gap: 0.2)), [])
        XCTAssertEqual(feed(&r, two(gap: 0.3)), [])
        XCTAssertEqual(feed(&r, []), [])
        // Hepsi kalktıktan sonra yeniden başlar.
        XCTAssertEqual(feed(&r, two(gap: 0.2)), [])
        XCTAssertEqual(feed(&r, two(gap: 0.27)), [.began])
    }

    func testClickCancels() {
        var r = begun()
        XCTAssertEqual(r.noteClick(), [.ended])
        XCTAssertFalse(r.isActive)
        XCTAssertEqual(feed(&r, two(gap: 0.35)), [])
        XCTAssertEqual(feed(&r, []), [])
        // Etkin değilken tıklama olay üretmez ama oturumu yine kapatır.
        var idle = PinchRecognizer()
        _ = feed(&idle, two(gap: 0.2))
        XCTAssertEqual(idle.noteClick(), [])
        XCTAssertEqual(feed(&idle, two(gap: 0.3)), [])
    }

    func testLiftEnds() {
        var r = begun()
        XCTAssertEqual(feed(&r, [TouchPoint(id: 1, x: 0.4, y: 0.7)]), [.ended])
        XCTAssertFalse(r.isActive)
        var r2 = begun()
        XCTAssertEqual(feed(&r2, []), [.ended])
        // Etkin değilken kalkış olay üretmez.
        XCTAssertEqual(feed(&r2, []), [])
    }

    func testPalmFingersIgnored() {
        var r = PinchRecognizer()
        let palm = TouchPoint(id: 9, x: 0.5, y: 0.1)
        XCTAssertEqual(feed(&r, two(gap: 0.2) + [palm]), [])
        XCTAssertEqual(feed(&r, two(gap: 0.27) + [palm]), [.began])
        XCTAssertEqual(feed(&r, two(gap: 0.3) + [TouchPoint(id: 9, x: 0.3, y: 0.15)]), [.step(1)])
        // Avuç değerken ön parmaklar kalkınca biter.
        XCTAssertEqual(feed(&r, [palm]), [.ended])
    }

    func testMovedSignsOnOpenAndClose() {
        var r = begun()
        // Açma: önce `.moved` (+), sonra adım; ilk kare çapaya (0.27) göre.
        let open = feedAll(&r, two(gap: 0.3))
        XCTAssertEqual(open.count, 2)
        XCTAssertEqual(moves(open).count, 1)
        XCTAssertEqual(moves(open)[0], 0.03, accuracy: 1e-5)
        XCTAssertEqual(open.last, .step(1))
        // Kapama: `.moved` (−).
        let close = feedAll(&r, two(gap: 0.29))
        XCTAssertEqual(moves(close).count, 1)
        XCTAssertLessThan(moves(close)[0], 0)
        // Sıfır değişimde olay yok.
        XCTAssertEqual(feedAll(&r, two(gap: 0.29)), [])
    }

    func testMovedSumEqualsDistanceChange() {
        var r = PinchRecognizer()
        XCTAssertEqual(feedAll(&r, two(gap: 0.2)), [])
        XCTAssertEqual(feedAll(&r, two(gap: 0.27)), [.began])
        var sum: Float = 0
        for gap: Float in [0.28, 0.31, 0.305, 0.36, 0.33, 0.4] {
            sum += moves(feedAll(&r, two(gap: gap))).reduce(0, +)
        }
        XCTAssertEqual(sum, 0.4 - 0.27, accuracy: 1e-4)
    }

    func testNoMovedWhileInactive() {
        var r = PinchRecognizer()
        XCTAssertEqual(feedAll(&r, two(gap: 0.2)), [])
        XCTAssertEqual(feedAll(&r, two(gap: 0.23)), [])
        // `.began` karesinde `.moved` yok.
        XCTAssertEqual(feedAll(&r, two(gap: 0.27)), [.began])
        XCTAssertEqual(feedAll(&r, []), [.ended])
        XCTAssertEqual(feedAll(&r, two(gap: 0.2)), [])
        XCTAssertEqual(feedAll(&r, two(gap: 0.22)), [])
    }

    func testSensitivityMapping() {
        XCTAssertEqual(PinchRecognizer.step(forSensitivity: 0), 0.05, accuracy: 1e-9)
        XCTAssertEqual(PinchRecognizer.step(forSensitivity: 1), 0.012, accuracy: 1e-9)
        XCTAssertEqual(PinchRecognizer.sensitivity(forStep: 0.05), 0, accuracy: 1e-9)
        XCTAssertEqual(PinchRecognizer.sensitivity(forStep: 0.012), 1, accuracy: 1e-9)
        let s = PinchRecognizer.sensitivity(forStep: PinchRecognizer.defaultStep)
        XCTAssertEqual(PinchRecognizer.step(forSensitivity: s), PinchRecognizer.defaultStep, accuracy: 1e-9)
        XCTAssertEqual(PinchRecognizer.step(forSensitivity: 5), 0.012, accuracy: 1e-9)
    }
}

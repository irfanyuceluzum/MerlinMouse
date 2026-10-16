import XCTest
@testable import MerlinCore

final class EdgeSlideRecognizerTests: XCTestCase {
    private var time = 0.0

    private func make(_ sides: Set<EdgeSide> = [.left, .right]) -> EdgeSlideRecognizer {
        var r = EdgeSlideRecognizer()
        r.enabledSides = sides
        return r
    }

    private func frame(_ points: [(Int32, Float, Float)]) -> TouchFrame {
        time += 0.01
        return TouchFrame(touches: points.map { TouchPoint(id: $0.0, x: $0.1, y: $0.2) }, timestamp: time)
    }

    @discardableResult
    private func feed(_ r: inout EdgeSlideRecognizer, _ points: [(Int32, Float, Float)]) -> [EdgeSlideEvent] {
        r.process(frame(points))
    }

    // MARK: Aday

    func testLandingInStripMakesCandidate() {
        var r = make()
        feed(&r, [])
        XCTAssertTrue(feed(&r, [(1, 0.05, 0.5)]).isEmpty)
        XCTAssertTrue(r.isCandidate)
        XCTAssertFalse(r.isActive)
        feed(&r, [])
        XCTAssertFalse(r.isCandidate)

        // Sağ kenar ve şeridin arka bölgede kalan kısmı da şerittir.
        feed(&r, [(2, 0.95, 0.2)])
        XCTAssertTrue(r.isCandidate)
    }

    func testLandingOutsideVerticalBoundsIsIgnored() {
        var r = make()
        // Varsayılan aralık 0.15…0.60: ön uçtaki (tıklama alanı) ve en arkadaki dokunuş aday olmaz.
        feed(&r, [(1, 0.05, 0.75)])
        XCTAssertFalse(r.isCandidate)
        feed(&r, [])
        feed(&r, [(2, 0.95, 0.05)])
        XCTAssertFalse(r.isCandidate)
        feed(&r, [])
        // Aralık değişince aynı nokta aday olur.
        r.bounds = EdgeStripBounds(bottom: 0.15, top: 0.80)
        feed(&r, [(3, 0.05, 0.75)])
        XCTAssertTrue(r.isCandidate)
    }

    func testOwnFingerLeavingStripKeepsSession() {
        var r = make()
        feed(&r, [(1, 0.05, 0.30)])
        XCTAssertEqual(feed(&r, [(1, 0.05, 0.24)]), [.began(.left)])
        // Alt ucun altına (arka, şerit dışı) kayan parmak avuç sayılmaz; oturum sürer.
        XCTAssertEqual(feed(&r, [(1, 0.05, 0.08)]), [.step(-1), .step(-1), .step(-1)])
        XCTAssertTrue(r.isActive)
        XCTAssertEqual(feed(&r, []), [.ended])
    }

    func testLandingOutsideStripIsIgnored() {
        var r = make()
        feed(&r, [(1, 0.5, 0.5)])
        XCTAssertFalse(r.isCandidate)
        // Ortada inip kenara kayan parmak aday olmaz.
        feed(&r, [(1, 0.05, 0.5)])
        feed(&r, [(1, 0.05, 0.7)])
        XCTAssertFalse(r.isCandidate)
        XCTAssertFalse(r.isActive)
    }

    func testOnlyOneFingerOnEmptySurface() {
        var r = make()
        // Aynı anda iki parmak inerse aday yok.
        feed(&r, [(1, 0.05, 0.5), (2, 0.5, 0.5)])
        XCTAssertFalse(r.isCandidate)
        // Biri kalkıp kenardaki kalsa da (yüzey boşalmadı) aday yok.
        feed(&r, [(1, 0.05, 0.5)])
        XCTAssertFalse(r.isCandidate)
    }

    func testDisabledSideIgnored() {
        var r = make([.right])
        feed(&r, [(1, 0.05, 0.5)])
        XCTAssertFalse(r.isCandidate)
        XCTAssertTrue(feed(&r, [(1, 0.05, 0.8)]).isEmpty)
        feed(&r, [])
        var none = make([])
        feed(&none, [(1, 0.05, 0.5)])
        feed(&none, [(1, 0.05, 0.8)])
        XCTAssertFalse(none.isCandidate)
        feed(&r, [(2, 0.97, 0.5)])
        XCTAssertTrue(r.isCandidate)
    }

    func testStripWidthChange() {
        var r = make()
        feed(&r, [(1, 0.15, 0.5)])
        XCTAssertFalse(r.isCandidate)
        feed(&r, [])
        r.edgeWidth = 0.20
        feed(&r, [(2, 0.15, 0.5)])
        XCTAssertTrue(r.isCandidate)
        feed(&r, [])
        feed(&r, [(3, 0.82, 0.5)])
        XCTAssertTrue(r.isCandidate)
        feed(&r, [])
        r.edgeWidth = 0.06
        feed(&r, [(4, 0.08, 0.5)])
        XCTAssertFalse(r.isCandidate)
        XCTAssertEqual(r.side(forX: 0.06), .left)
        XCTAssertEqual(r.side(forX: 0.95), .right)
        XCTAssertNil(r.side(forX: 0.5))
    }

    // MARK: Başlama

    func testBeginThresholdAndVerticality() {
        var r = make()
        feed(&r, [(1, 0.05, 0.50)])
        // Eşik 0.04: 0.03 başlatmaz.
        XCTAssertTrue(feed(&r, [(1, 0.05, 0.53)]).isEmpty)
        // Dikeylik |dy| > 3|dx|: dy 0.045, dx 0.02 başlatmaz (eski 2× kuralında başlardı).
        XCTAssertTrue(feed(&r, [(1, 0.07, 0.545)]).isEmpty)
        XCTAssertFalse(r.isActive)
        XCTAssertEqual(feed(&r, [(1, 0.06, 0.55)]), [.began(.left)])
        XCTAssertTrue(r.isActive)
        XCTAssertTrue(r.isCandidate)
    }

    func testBeganReportsRightSide() {
        var r = make()
        feed(&r, [(1, 0.95, 0.5)])
        XCTAssertEqual(feed(&r, [(1, 0.95, 0.45)]), [.began(.right)])
    }

    // MARK: Adımlar

    func testIncreaseDecreaseAndMultiStep() {
        var r = make()
        r.step = 0.05
        feed(&r, [(1, 0.05, 0.30)])
        XCTAssertEqual(feed(&r, [(1, 0.05, 0.35)]), [.began(.left)])
        XCTAssertTrue(feed(&r, [(1, 0.05, 0.38)]).isEmpty)
        // Yukarı (öne) = artır.
        XCTAssertEqual(feed(&r, [(1, 0.05, 0.405)]), [.step(1)])
        // Büyük sıçrama: birden çok adım.
        XCTAssertEqual(feed(&r, [(1, 0.05, 0.56)]), [.step(1), .step(1), .step(1)])
        // Aşağı = azalt.
        XCTAssertEqual(feed(&r, [(1, 0.05, 0.48)]), [.step(-1)])
        XCTAssertEqual(feed(&r, [(1, 0.05, 0.38)]), [.step(-1), .step(-1)])
    }

    func testLiftEndsActiveSession() {
        var r = make()
        feed(&r, [(1, 0.05, 0.5)])
        feed(&r, [(1, 0.05, 0.6)])
        XCTAssertEqual(feed(&r, []), [.ended])
        XCTAssertFalse(r.isActive)
        XCTAssertFalse(r.isCandidate)
        // Etkin olmayan adayın kalkışı olay üretmez.
        feed(&r, [(2, 0.05, 0.5)])
        XCTAssertTrue(feed(&r, []).isEmpty)
    }

    // MARK: İptal

    func testSecondFingerCancels() {
        var r = make()
        feed(&r, [(1, 0.05, 0.5)])
        feed(&r, [(1, 0.05, 0.6)])
        XCTAssertEqual(feed(&r, [(1, 0.05, 0.6), (2, 0.5, 0.5)]), [.ended])
        XCTAssertFalse(r.isCandidate)
        // Tüm parmaklar kalkana kadar yeni aday ve olay yok.
        XCTAssertTrue(feed(&r, [(1, 0.05, 0.8)]).isEmpty)
        XCTAssertFalse(r.isCandidate)
        feed(&r, [])
        feed(&r, [(3, 0.05, 0.5)])
        XCTAssertTrue(r.isCandidate)
    }

    func testSecondFingerCancelsCandidateWithoutEvent() {
        var r = make()
        feed(&r, [(1, 0.05, 0.5)])
        XCTAssertTrue(feed(&r, [(1, 0.05, 0.5), (2, 0.5, 0.5)]).isEmpty)
        XCTAssertFalse(r.isCandidate)
    }

    func testClickCancels() {
        var r = make()
        feed(&r, [(1, 0.05, 0.5)])
        feed(&r, [(1, 0.05, 0.6)])
        XCTAssertEqual(r.noteClick(), [.ended])
        XCTAssertFalse(r.isCandidate)
        XCTAssertFalse(r.isActive)
        XCTAssertTrue(feed(&r, [(1, 0.05, 0.9)]).isEmpty)
        XCTAssertTrue(feed(&r, []).isEmpty)
        // Aday iken tıklama: olay yok, aday biter.
        feed(&r, [(2, 0.05, 0.5)])
        XCTAssertTrue(r.noteClick().isEmpty)
        XCTAssertFalse(r.isCandidate)
    }

    func testClickOnCandidateNeverStartsSession() {
        // Şeritte duran parmakla basma: tıklama adayı bitirir, ardından gelen dikey hareket kenar hareketi başlatmaz.
        var r = make()
        feed(&r, [(1, 0.05, 0.40)])
        XCTAssertTrue(r.noteClick().isEmpty)
        XCTAssertTrue(feed(&r, [(1, 0.05, 0.55)]).isEmpty)
        XCTAssertTrue(feed(&r, [(1, 0.05, 0.30)]).isEmpty)
        XCTAssertFalse(r.isActive)
        XCTAssertFalse(r.isCandidate)
        XCTAssertTrue(feed(&r, []).isEmpty)
    }

    func testClickOnEmptySurfaceDoesNotBlockNextTouch() {
        var r = make()
        feed(&r, [])
        r.noteClick()
        feed(&r, [(1, 0.05, 0.5)])
        XCTAssertTrue(r.isCandidate)
    }

    // MARK: Avuç

    /// Arka bölgede (y < 0.4) ve şerit dışında: avuç.
    private let palm: (Int32, Float, Float) = (9, 0.5, 0.15)

    func testPalmClassification() {
        let r = make()
        XCTAssertTrue(r.isPalm(TouchPoint(id: 1, x: 0.5, y: 0.15)))
        // Arkada ama şerit dikdörtgeninde (0.15…0.60): avuç değil.
        XCTAssertFalse(r.isPalm(TouchPoint(id: 1, x: 0.05, y: 0.25)))
        XCTAssertFalse(r.isPalm(TouchPoint(id: 1, x: 0.95, y: 0.25)))
        // Kenar sütununda ama şeridin altında (arka): avuç.
        XCTAssertTrue(r.isPalm(TouchPoint(id: 1, x: 0.05, y: 0.05)))
        // Önde: avuç değil.
        XCTAssertFalse(r.isPalm(TouchPoint(id: 1, x: 0.5, y: 0.6)))
    }

    func testFingerLandsAtEdgeWhilePalmRests() {
        var r = make()
        feed(&r, [])
        feed(&r, [palm])
        XCTAssertFalse(r.isCandidate)
        feed(&r, [palm, (1, 0.05, 0.50)])
        XCTAssertTrue(r.isCandidate)
        XCTAssertEqual(feed(&r, [palm, (1, 0.05, 0.55)]), [.began(.left)])
        XCTAssertEqual(feed(&r, [palm, (1, 0.05, 0.61)]), [.step(1)])
        XCTAssertEqual(feed(&r, [palm, (1, 0.05, 0.44)]), [.step(-1), .step(-1), .step(-1)])
        // Parmak kalkar, avuç kalır: oturum biter.
        XCTAssertEqual(feed(&r, [palm]), [.ended])
        XCTAssertFalse(r.isCandidate)
        // Avuç hâlâ değerken yeni parmak yine aday olur.
        feed(&r, [palm, (2, 0.95, 0.5)])
        XCTAssertTrue(r.isCandidate)
    }

    func testPalmLandingAndLiftingDoesNotCancel() {
        var r = make()
        feed(&r, [(1, 0.05, 0.50)])
        XCTAssertEqual(feed(&r, [(1, 0.05, 0.55)]), [.began(.left)])
        XCTAssertTrue(feed(&r, [(1, 0.05, 0.56), palm]).isEmpty)
        XCTAssertTrue(r.isActive)
        XCTAssertEqual(feed(&r, [(1, 0.05, 0.61), palm]), [.step(1)])
        XCTAssertTrue(feed(&r, [(1, 0.05, 0.62)]).isEmpty)
        XCTAssertTrue(r.isActive)
        XCTAssertTrue(r.isCandidate)
    }

    func testRealSecondFingerStillCancelsWithPalm() {
        // Önde ikinci parmak.
        var r = make()
        feed(&r, [palm, (1, 0.05, 0.50)])
        feed(&r, [palm, (1, 0.05, 0.56)])
        XCTAssertEqual(feed(&r, [palm, (1, 0.05, 0.56), (2, 0.5, 0.7)]), [.ended])
        XCTAssertFalse(r.isCandidate)
        // İkinci parmak kalksa da avuç değerken engel sürmez; avuç dışı yüzey boşalınca kalkar.
        XCTAssertTrue(feed(&r, [palm, (1, 0.05, 0.70)]).isEmpty)
        XCTAssertFalse(r.isCandidate)
        feed(&r, [palm])
        feed(&r, [palm, (3, 0.05, 0.5)])
        XCTAssertTrue(r.isCandidate)

        // Arkada ama başka şeritte ikinci parmak da gerçek parmaktır.
        var s = make()
        feed(&s, [(1, 0.05, 0.50)])
        feed(&s, [(1, 0.05, 0.56)])
        XCTAssertEqual(feed(&s, [(1, 0.05, 0.56), (2, 0.95, 0.25)]), [.ended])
        XCTAssertFalse(s.isCandidate)
    }

    func testPalmWithDisabledEdgesChangesNothing() {
        var r = make([])
        feed(&r, [palm])
        feed(&r, [palm, (1, 0.05, 0.50)])
        XCTAssertTrue(feed(&r, [palm, (1, 0.05, 0.70)]).isEmpty)
        XCTAssertFalse(r.isCandidate)
        XCTAssertFalse(r.isActive)
    }

    // MARK: Hassasiyet

    func testSensitivityMapping() {
        let range = EdgeSlideRecognizer.stepRange
        XCTAssertEqual(EdgeSlideRecognizer.step(forSensitivity: 0), range.upperBound, accuracy: 1e-9)
        XCTAssertEqual(EdgeSlideRecognizer.step(forSensitivity: 1), range.lowerBound, accuracy: 1e-9)
        XCTAssertEqual(EdgeSlideRecognizer.sensitivity(forStep: EdgeSlideRecognizer.step(forSensitivity: 0.3)), 0.3,
                       accuracy: 1e-9)
        XCTAssertTrue(range.contains(EdgeSlideRecognizer.defaultStep))
        XCTAssertTrue(EdgeSlideRecognizer.edgeWidthRange.contains(EdgeSlideRecognizer.defaultEdgeWidth))
        XCTAssertEqual(EdgeSide(zone: .leftEdge), .left)
        XCTAssertEqual(EdgeSide(zone: .rightEdge), .right)
        XCTAssertNil(EdgeSide(zone: .left))
        XCTAssertEqual(EdgeSide.right.zone, .rightEdge)
    }
}

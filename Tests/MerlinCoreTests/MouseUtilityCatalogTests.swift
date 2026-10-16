import XCTest
@testable import MerlinCore

final class MouseUtilityCatalogTests: XCTestCase {
    private func ids(_ running: [(bundleID: String?, name: String?)]) -> [String] {
        MouseUtilityCatalog.detect(running: running).map(\.id)
    }

    func testMatchesByBundlePrefix() {
        XCTAssertEqual(ids([(bundleID: "com.nuebling.mac-mouse-fix.helper", name: "Helper")]), ["macmousefix"])
        XCTAssertEqual(ids([(bundleID: "com.logi.optionsplus", name: nil)]), ["logioptions"])
        // Logitech'in fare dışı uygulamaları (ör. Logi Tune) Options+ sayılmaz.
        XCTAssertEqual(ids([(bundleID: "com.logi.tune", name: "Logi Tune")]), [])
        XCTAssertEqual(ids([(bundleID: "jp.plentycom.boa.SteerMouse", name: nil)]), ["steermouse"])
    }

    func testMatchesByNameKeyword() {
        XCTAssertEqual(ids([(bundleID: nil, name: "SmoothScroll")]), ["smoothscroll"])
        XCTAssertEqual(ids([(bundleID: "org.example.x", name: "USB Overdrive Helper")]), ["usboverdrive"])
        XCTAssertEqual(ids([(bundleID: nil, name: "Scroll Reverser")]), ["scrollreverser"])
    }

    func testCaseInsensitive() {
        XCTAssertEqual(ids([(bundleID: "COM.JITOUCH.JITOUCH", name: nil)]), ["jitouch"])
        XCTAssertEqual(ids([(bundleID: nil, name: "MIDDLECLICK")]), ["middleclick"])
        XCTAssertEqual(ids([(bundleID: nil, name: "Mac MOUSE Fix")]), ["macmousefix"])
    }

    func testMosMatchesOnlyByBundleID() {
        XCTAssertEqual(ids([(bundleID: "com.caldis.Mos", name: "Mos")]), ["mos"])
        XCTAssertEqual(ids([(bundleID: nil, name: "Mos")]), [])
        XCTAssertEqual(ids([(bundleID: "com.example.mosaic", name: "Mosaic")]), [])
    }

    func testSelfAndBTTNeverMatch() {
        XCTAssertEqual(ids([(bundleID: "dev.merlinmouse.MerlinMouse", name: "Merlin Mouse")]), [])
        XCTAssertEqual(ids([(bundleID: "com.hegenberg.BetterTouchTool", name: "BetterTouchTool")]), [])
        // Adında anahtar kelime olsa da dışlananlar eşleşmez.
        XCTAssertEqual(ids([(bundleID: "dev.merlinmouse.test", name: "MiddleClick")]), [])
        XCTAssertEqual(ids([(bundleID: nil, name: "BetterTouchTool SmoothScroll")]), [])
    }

    func testDetectIsUniqueAndInCatalogOrder() {
        let running: [(bundleID: String?, name: String?)] = [
            (bundleID: "com.logi.optionsplus", name: "Logi Options+"),
            (bundleID: "com.logi.optionsplus.agent", name: "logioptionsplus_agent"),
            (bundleID: "com.jitouch.Jitouch", name: "Jitouch"),
            (bundleID: "com.nuebling.mac-mouse-fix", name: "Mac Mouse Fix"),
            (bundleID: "com.nuebling.mac-mouse-fix.helper", name: "Mac Mouse Fix Helper"),
            (bundleID: "com.apple.finder", name: "Finder"),
        ]
        XCTAssertEqual(ids(running), ["macmousefix", "jitouch", "logioptions"])
    }

    func testWarningTexts() {
        let mmf = MouseUtilityCatalog.all.first { $0.id == "macmousefix" }!
        XCTAssertEqual(mmf.warningTitle, "Mac Mouse Fix çalışıyor")
        XCTAssertEqual(mmf.warningDetail,
                       "Kaydırmayı değiştirir; çimdikleme ve kenar kaydırmada kaydırma engeli beklenmedik davranabilir. "
                       + "Fare tuşlarını değiştirir; orta tuş dönüşümü iki kez işlenebilir.")
        let jitouch = MouseUtilityCatalog.all.first { $0.id == "jitouch" }!
        XCTAssertEqual(jitouch.warningDetail, "Magic Mouse hareketlerini işler; aynı hareket iki kez çalışabilir.")
        let mos = MouseUtilityCatalog.all.first { $0.id == "mos" }!
        XCTAssertEqual(mos.warningDetail,
                       "Kaydırmayı değiştirir; çimdikleme ve kenar kaydırmada kaydırma engeli beklenmedik davranabilir.")
    }
}

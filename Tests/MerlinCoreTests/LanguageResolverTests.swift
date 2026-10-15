import XCTest
@testable import MerlinCore

final class LanguageResolverTests: XCTestCase {
    func testSystemPicksTurkish() {
        XCTAssertEqual(AppLanguage.resolve(.system, preferred: ["tr-TR"]), "tr")
    }

    func testSystemPicksFirstSupported() {
        XCTAssertEqual(AppLanguage.resolve(.system, preferred: ["de-DE", "en-GB"]), "en")
        XCTAssertEqual(AppLanguage.resolve(.system, preferred: ["fr", "tr"]), "tr")
    }

    func testSystemFallsBackToEnglish() {
        XCTAssertEqual(AppLanguage.resolve(.system, preferred: ["de-DE"]), "en")
        XCTAssertEqual(AppLanguage.resolve(.system, preferred: []), "en")
    }

    func testExplicitChoiceWins() {
        XCTAssertEqual(AppLanguage.resolve(.tr, preferred: ["en-US"]), "tr")
        XCTAssertEqual(AppLanguage.resolve(.en, preferred: ["tr-TR"]), "en")
    }

    func testStoredValueParsing() {
        XCTAssertEqual(AppLanguage.from(stored: "tr"), .tr)
        XCTAssertEqual(AppLanguage.from(stored: "bilinmeyen"), .system)
        XCTAssertEqual(AppLanguage.resolve("system", preferred: ["tr"]), "tr")
    }
}

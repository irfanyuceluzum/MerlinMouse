import XCTest
@testable import MerlinCore

final class LocalizationTests: XCTestCase {
    private var projectRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Kaynak dosyalardaki literal anahtarlar; `pattern` 1. grupta tür (`t`/`f`/`L`/`LF`), 2. grupta anahtar yakalar.
    private func keys(in subpath: String, pattern: String, formattedKinds: Set<String>)
        throws -> (all: Set<String>, formatted: Set<String>) {
        let dir = projectRoot.appendingPathComponent(subpath)
        let files = try XCTUnwrap(FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil))
        let re = try NSRegularExpression(pattern: pattern)
        var all = Set<String>(), formatted = Set<String>()
        for case let url as URL in files where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let kind = Range(m.range(at: 1), in: text),
                      let key = Range(m.range(at: 2), in: text) else { continue }
                all.insert(String(text[key]))
                if formattedKinds.contains(String(text[kind])) { formatted.insert(String(text[key])) }
            }
        }
        return (all, formatted)
    }

    /// Core: `MerlinText.t("…")` / `MerlinText.f("…"`; uygulama: `L("…")` / `LF("…"`.
    private func sourceKeys() throws -> (all: Set<String>, formatted: Set<String>) {
        let core = try keys(in: "Sources/MerlinCore", pattern: #"MerlinText\.([tf])\("((?:[^"\\]|\\.)*)""#,
                            formattedKinds: ["f"])
        let app = try keys(in: "Sources/MerlinMouse", pattern: #"\b(LF?)\("((?:[^"\\]|\\.)*)""#,
                           formattedKinds: ["LF"])
        return (core.all.union(app.all), core.formatted.union(app.formatted))
    }

    private func englishTable() throws -> [String: String] {
        let url = projectRoot.appendingPathComponent("Resources/en.lproj/Localizable.strings")
        let dict = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String],
                                 "Localizable.strings okunamadı: \(url.path)")
        return dict
    }

    private func placeholders(_ s: String) -> [String] {
        let re = try! NSRegularExpression(pattern: #"%[0-9.]*(?:lld|ld|d|@|f|s)"#)
        return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap {
            Range($0.range, in: s).map { String(s[$0]) }
        }
    }

    func testEveryKeyHasEnglishTranslation() throws {
        let keys = try sourceKeys().all
        XCTAssertGreaterThan(keys.count, 100, "Anahtarlar toplanamadı")
        let table = try englishTable()
        let missing = keys.filter { table[$0] == nil || table[$0]!.isEmpty }.sorted()
        XCTAssertTrue(missing.isEmpty, "İngilizce karşılığı eksik anahtarlar:\n" + missing.joined(separator: "\n"))
    }

    func testFormatKeysKeepPlaceholders() throws {
        let table = try englishTable()
        for key in try sourceKeys().formatted.sorted() {
            guard let en = table[key] else { continue }  // eksikleri diğer test bildirir
            XCTAssertEqual(placeholders(en), placeholders(key), "Yer tutucular farklı: \(key)")
        }
    }

    func testEnglishLookupTranslates() throws {
        let table = try englishTable()
        let saved = MerlinText.lookup
        MerlinText.lookup = { table[$0] ?? $0 }
        defer { MerlinText.lookup = saved }

        XCTAssertEqual(Trigger(kind: .press, fingers: 2).title, "Press with two fingers")
        XCTAssertEqual(Trigger(kind: .press, fingers: 1, zone: .right).title, "Press on the right zone")
        XCTAssertEqual(Trigger(kind: .swipe, fingers: 3, direction: .left).title, "Swipe left with three fingers")
        XCTAssertEqual(Trigger(kind: .press, fingers: 6).title, "Press with 6 fingers")
        XCTAssertEqual(Trigger(kind: .press, modifier: .fn).title, "Fn + click")
        XCTAssertEqual(Zone.rear.displayName, "Back (logo)")
        XCTAssertEqual(GestureAction.middleClick.title, "Middle click")
        XCTAssertEqual(GestureAction.openApp(path: "/x", name: "Notes").title, "Open Notes")

        let probe = GestureBinding(trigger: Trigger(kind: .press, fingers: 1, zone: .left), action: .middleClick)
        let conflicts = ConflictChecker.check(probe, among: [], env: ConflictEnvironment())
        XCTAssertEqual(conflicts.first?.title, "Regular left click")
        XCTAssertEqual(DefaultBindings.definitions.first?.title, "Click the center zone")
        XCTAssertEqual(GesturePresets.all.first?.title, "Click the center zone")
        XCTAssertEqual(SystemGestureCatalog.freeGestures.last, "Fn + click / drag")
    }

    func testAppSourcesHaveNoUntranslatedTextLiterals() throws {
        // `Text("` + harf ile başlayan literal çevrilmeden kalmamalı: `Text(L("…"))` ya da `Text(verbatim:)` kullanılır.
        let dir = projectRoot.appendingPathComponent("Sources/MerlinMouse")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil))
        let re = try NSRegularExpression(pattern: #"Text\("\p{L}[^"]*""#)
        var offenders: [String] = []
        for case let url as URL in files where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let r = Range(m.range, in: text) {
                    offenders.append("\(url.lastPathComponent): \(text[r])")
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty, "Çevrilmemiş Text literal'leri:\n" + offenders.joined(separator: "\n"))
    }

    func testEnglishTableHasNoDuplicateKeys() throws {
        let url = projectRoot.appendingPathComponent("Resources/en.lproj/Localizable.strings")
        let text = try String(contentsOf: url, encoding: .utf8)
        let re = try NSRegularExpression(pattern: #"^"((?:[^"\\]|\\.)*)"\s*="#, options: .anchorsMatchLines)
        var seen = Set<String>(), dup: [String] = []
        for m in re.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let r = Range(m.range(at: 1), in: text) else { continue }
            if !seen.insert(String(text[r])).inserted { dup.append(String(text[r])) }
        }
        XCTAssertTrue(dup.isEmpty, "Yinelenen anahtarlar:\n" + dup.joined(separator: "\n"))
    }

    func testDefaultLookupIsTurkishIdentity() {
        XCTAssertEqual(MerlinText.t("Orta tıklama"), "Orta tıklama")
        XCTAssertEqual(MerlinText.f("%d parmakla", 6), "6 parmakla")
        XCTAssertEqual(Trigger(kind: .press, fingers: 2).title, "İki parmakla bas")
        XCTAssertEqual(Trigger(kind: .swipe, fingers: 3, direction: .left).title, "Üç parmakla sola kaydır")
        XCTAssertEqual(Trigger(kind: .press, modifier: .fn).title, "Fn + bas")
    }
}

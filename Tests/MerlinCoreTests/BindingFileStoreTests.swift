import XCTest
@testable import MerlinCore

final class BindingFileStoreTests: XCTestCase {
    private let legacy = LegacyFlags(zoneClick: true, twoFingerClick: false, threeFingerClick: true,
                                     threeFingerTap: true, fnDrag: false)

    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    func testMissingFileCreatedFromLegacy() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = BindingFileStore(directory: dir, legacy: { self.legacy }, log: { _ in })
        let set = store.load()
        XCTAssertEqual(set.bindings.map(\.enabled), DefaultBindings.from(legacy: legacy).map(\.enabled))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func testCorruptFileBackedUp() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = BindingFileStore(directory: dir, legacy: { self.legacy }, log: { _ in })
        try Data("{bozuk".utf8).write(to: store.fileURL)
        var logged: [String] = []
        let s2 = BindingFileStore(directory: dir, legacy: { self.legacy }, log: { logged.append($0) })
        let set = s2.load()
        XCTAssertEqual(set.bindings.map(\.enabled), DefaultBindings.from(legacy: legacy).map(\.enabled))
        XCTAssertFalse(logged.isEmpty)
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(names.contains { $0.hasPrefix("bindings.bozuk-") && $0.hasSuffix(".json") })
        // Yeni dosya geçerli olmalı.
        XCTAssertEqual(store.load(), set)
    }

    func testSaveLoadRoundTrip() {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = BindingFileStore(directory: dir, legacy: { self.legacy }, log: { _ in })
        var set = store.load()
        set.bindings[0].enabled.toggle()
        set.bindings.append(GestureBinding(trigger: Trigger(kind: .tap, fingers: 3), action: .back,
                                           appBundleID: "com.example.app", appName: "Örnek"))
        store.save(set)
        XCTAssertEqual(store.load(), set)
    }
}

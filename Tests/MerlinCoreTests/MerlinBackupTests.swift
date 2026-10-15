import XCTest
@testable import MerlinCore

final class MerlinBackupTests: XCTestCase {
    private func sample() -> MerlinBackup {
        let b = GestureBinding(trigger: Trigger(kind: .press, fingers: 1, zone: .left), action: .middleClick)
        var set = BindingSet(bindings: [b], profiles: [ProfileApp(bundleID: "com.x", name: "X")])
        set.preserved = [.string("bilinmeyen")]
        let st = BackupSettings(zoneLayout: .standard, appearance: "dark", language: "en", flipY: true,
                                blockScrollWhileDragging: false, calm3DScroll: true, batteryAlertsEnabled: false)
        return MerlinBackup(createdAt: Date(timeIntervalSince1970: 1_700_000_000), bindings: set, settings: st)
    }

    func testRoundTrip() throws {
        let original = sample()
        let decoded = try MerlinBackup.decode(try original.encode())
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.bindings.preserved.count, 1)
    }

    func testMissingSettingsAreNil() throws {
        let json = #"{"version":1,"createdAt":"2024-01-01T00:00:00Z","app":"Merlin Mouse","bindings":{"version":1,"bindings":[]},"settings":{"flipY":true}}"#
        let b = try MerlinBackup.decode(Data(json.utf8))
        XCTAssertEqual(b.settings.flipY, true)
        XCTAssertNil(b.settings.zoneLayout)
        XCTAssertNil(b.settings.appearance)
        XCTAssertNil(b.settings.batteryAlertsEnabled)
    }

    func testWrongFileThrows() {
        XCTAssertThrowsError(try MerlinBackup.decode(Data("merhaba".utf8))) {
            XCTAssertEqual($0 as? MerlinBackupError, .notABackup)
        }
        let other = #"{"version":1,"app":"Baska","bindings":{"bindings":[]},"settings":{}}"#
        XCTAssertThrowsError(try MerlinBackup.decode(Data(other.utf8))) {
            XCTAssertEqual($0 as? MerlinBackupError, .notABackup)
        }
    }

    func testFutureVersionThrows() {
        let json = #"{"version":2,"app":"Merlin Mouse","yeni":true}"#
        XCTAssertThrowsError(try MerlinBackup.decode(Data(json.utf8))) {
            XCTAssertEqual($0 as? MerlinBackupError, .futureVersion(2))
        }
    }
}

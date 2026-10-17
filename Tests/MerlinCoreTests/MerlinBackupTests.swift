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

    func testRoundTripWithLaterSettings() throws {
        var original = sample()
        original.settings.pinchInvert = true
        original.settings.pinchStep = 0.03
        original.settings.edgeWidth = 0.12
        original.settings.edgeStep = 0.06
        original.settings.edgeFineSteps = true
        original.settings.edgeInvert = true
        original.settings.edgeBounds = EdgeStripBounds(bottom: 0.2, top: 0.7)
        original.settings.trackpadCorners = TrackpadCornerLayout(width: 0.2, height: 0.25)
        original.settings.editingDevice = InputDeviceKind.trackpad.rawValue
        let decoded = try MerlinBackup.decode(try original.encode())
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.settings.edgeBounds, EdgeStripBounds(bottom: 0.2, top: 0.7))
        XCTAssertEqual(decoded.settings.trackpadCorners, TrackpadCornerLayout(width: 0.2, height: 0.25))
        // Geçerli değerler geri yüklemede değişmez.
        XCTAssertEqual(decoded.settings.restorable(), original.settings)
    }

    func testOldBackupLeavesLaterSettingsNil() throws {
        let json = #"{"version":1,"createdAt":"2024-01-01T00:00:00Z","app":"Merlin Mouse","bindings":{"version":1,"bindings":[]},"settings":{"flipY":true,"appearance":"dark","calm3DScroll":false}}"#
        let s = try MerlinBackup.decode(Data(json.utf8)).settings
        XCTAssertEqual(s.flipY, true)
        XCTAssertEqual(s.calm3DScroll, false)
        for value in [s.pinchInvert, s.edgeFineSteps, s.edgeInvert] { XCTAssertNil(value) }
        for value in [s.pinchStep, s.edgeWidth, s.edgeStep] { XCTAssertNil(value) }
        XCTAssertNil(s.edgeBounds)
        XCTAssertNil(s.trackpadCorners)
        XCTAssertNil(s.editingDevice)
        // Sıkıştırma eksik alanı doldurmaz: geri yüklemede mevcut değer değişmez.
        let r = s.restorable()
        XCTAssertNil(r.pinchStep)
        XCTAssertNil(r.edgeWidth)
        XCTAssertNil(r.edgeStep)
        XCTAssertNil(r.edgeBounds)
        XCTAssertNil(r.trackpadCorners)
        XCTAssertNil(r.zoneLayout)
        XCTAssertNil(r.editingDevice)
        XCTAssertEqual(r.flipY, true)
    }

    func testRestorableClampsValues() {
        let s = BackupSettings(pinchStep: 5, edgeWidth: -1, edgeStep: 0.0001,
                               edgeBounds: EdgeStripBounds(bottom: 0.8, top: 0.95),
                               trackpadCorners: TrackpadCornerLayout(width: 1, height: 0.01),
                               editingDevice: "bilinmeyen-aygit")
        let r = s.restorable()
        XCTAssertEqual(r.pinchStep, PinchRecognizer.stepRange.upperBound)
        XCTAssertEqual(r.edgeWidth, EdgeSlideRecognizer.edgeWidthRange.lowerBound)
        XCTAssertEqual(r.edgeStep, EdgeSlideRecognizer.stepRange.lowerBound)
        XCTAssertEqual(r.edgeBounds, EdgeStripBounds(bottom: 0.8, top: 0.95).clamped())
        XCTAssertEqual(r.edgeBounds?.top, EdgeStripBounds.maxTop)
        XCTAssertEqual(r.trackpadCorners, TrackpadCornerLayout(width: TrackpadCornerLayout.range.upperBound,
                                                               height: TrackpadCornerLayout.range.lowerBound))
        XCTAssertNil(r.editingDevice)
        XCTAssertEqual(BackupSettings(editingDevice: "magicMouse").restorable().editingDevice, "magicMouse")
        XCTAssertNil(BackupSettings(pinchStep: .nan).restorable().pinchStep)
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

import XCTest
@testable import MerlinCore

/// Aygıt katmanı: atama aygıtı, eski sürüm güvenli kodlama, aygıta göre eşleştirme ve aygıt sınıflaması.
final class InputDeviceTests: XCTestCase {
    private let env = ConflictEnvironment()
    private let three = Trigger(kind: .press, fingers: 3)

    private func keys(_ b: GestureBinding) throws -> Set<String> {
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(b)) as? [String: Any])
        return Set(obj.keys)
    }

    // MARK: Model

    func testKindsAndNames() {
        XCTAssertEqual(InputDeviceKind.allCases, [.magicMouse, .trackpad])
        XCTAssertEqual(InputDeviceKind.magicMouse.rawValue, "magicMouse")
        XCTAssertEqual(InputDeviceKind.magicMouse.displayName, "Magic Mouse")
        XCTAssertEqual(InputDeviceKind.trackpad.displayName, "Trackpad")
        XCTAssertEqual(GestureBinding(trigger: three, action: .middleClick).device, .magicMouse)
    }

    // MARK: Kodlama

    func testMagicMouseWritesLegacyKeySet() throws {
        let plain = GestureBinding(trigger: three, action: .middleClick)
        XCTAssertEqual(try keys(plain), ["id", "trigger", "action", "enabled"])
        let full = GestureBinding(trigger: three, action: .back, enabled: false, appBundleID: "com.x", appName: "X",
                                  builtInKey: "three-finger")
        XCTAssertEqual(try keys(full), ["id", "trigger", "action", "enabled", "appBundleID", "appName", "builtInKey"])
    }

    func testMagicMouseBytesUnchangedForOldFile() throws {
        // Eski biçimli bir dosya çözülüp yeniden yazılınca (sıralı anahtarlarla) birebir aynı kalır.
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let b = GestureBinding(trigger: three, action: .middleClick, appBundleID: "com.x", appName: "X")
        let old = try enc.encode(BindingSet(bindings: [b]))
        let again = try enc.encode(JSONDecoder().decode(BindingSet.self, from: old))
        XCTAssertEqual(again, old)
    }

    func testTrackpadUsesDeviceTriggerKey() throws {
        let b = GestureBinding(trigger: three, action: .middleClick, device: .trackpad)
        let k = try keys(b)
        XCTAssertTrue(k.contains("deviceTrigger"))
        XCTAssertTrue(k.contains("device"))
        XCTAssertFalse(k.contains("trigger"))
        let back = try JSONDecoder().decode(GestureBinding.self, from: JSONEncoder().encode(b))
        XCTAssertEqual(back, b)
        XCTAssertEqual(back.device, .trackpad)
    }

    func testOldRecordWithoutDeviceIsMagicMouse() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","trigger":{"kind":"press","fingers":2,"zone":"any","direction":"up","modifier":"none"},"action":{"type":"middleClick"},"enabled":true}"#
        let b = try JSONDecoder().decode(GestureBinding.self, from: Data(json.utf8))
        XCTAssertEqual(b.device, .magicMouse)
        XCTAssertEqual(b.trigger, Trigger(kind: .press, fingers: 2))
    }

    /// Eski sürümün çözücüsünün taklidi: `trigger` zorunlu, `device` bilinmiyor.
    private struct LegacyBinding: Decodable {
        var id: UUID
        var trigger: Trigger
        var action: GestureAction
        var enabled: Bool
    }

    func testLegacyDecoderCannotReadTrackpadBinding() throws {
        let mouse = try JSONEncoder().encode(GestureBinding(trigger: three, action: .middleClick))
        XCTAssertNoThrow(try JSONDecoder().decode(LegacyBinding.self, from: mouse))
        let pad = try JSONEncoder().encode(GestureBinding(trigger: three, action: .middleClick, device: .trackpad))
        XCTAssertThrowsError(try JSONDecoder().decode(LegacyBinding.self, from: pad))
    }

    func testSetRoundTripKeepsBothDevices() throws {
        let m = GestureBinding(trigger: three, action: .middleClick)
        let t = GestureBinding(trigger: three, action: .back, device: .trackpad)
        let set = BindingSet(bindings: [m, t])
        let back = try JSONDecoder().decode(BindingSet.self, from: JSONEncoder().encode(set))
        XCTAssertEqual(back.bindings, [m, t])
        XCTAssertTrue(back.preserved.isEmpty)
    }

    // MARK: Eşleştirme

    func testIndexSeparatesDevices() {
        let m = GestureBinding(trigger: three, action: .middleClick)
        let t = GestureBinding(trigger: three, action: .back, device: .trackpad)
        let tap = GestureBinding(trigger: Trigger(kind: .doubleTap, fingers: 2), action: .back, device: .trackpad)
        let idx = BindingIndex(bindings: [t, m, tap])
        XCTAssertEqual(idx.match(three, bundleID: nil)?.id, m.id)
        XCTAssertEqual(idx.match(three, bundleID: nil, device: .magicMouse)?.id, m.id)
        XCTAssertEqual(idx.match(three, bundleID: nil, device: .trackpad)?.id, t.id)
        // 4 → 3 geri düşmesi de aygıt içinde.
        XCTAssertEqual(idx.match(Trigger(kind: .press, fingers: 4), bundleID: nil, device: .trackpad)?.id, t.id)
        // Çift dokunma ve şekil sorguları aygıta göre.
        XCTAssertFalse(idx.hasDoubleTap(fingers: 2))
        XCTAssertTrue(idx.hasDoubleTap(fingers: 2, device: .trackpad))
        XCTAssertFalse(idx.hasBinding(kind: .doubleTap, fingers: 2))
        XCTAssertTrue(idx.hasBinding(kind: .press, fingers: 3))
        // Yalnız trackpad ataması varken fare eşleşmez.
        XCTAssertNil(BindingIndex(bindings: [t]).match(three, bundleID: nil))
    }

    // MARK: Çakışma ve göçler

    func testSameTriggerOnOtherDeviceIsNotDuplicate() {
        let m = GestureBinding(trigger: three, action: .middleClick)
        let t = GestureBinding(trigger: three, action: .back, device: .trackpad)
        XCTAssertFalse(ConflictChecker.check(t, among: [m, t], env: env).contains { $0.level == .duplicate })
        let mOff = GestureBinding(trigger: three, action: .forward, enabled: false)
        XCTAssertFalse(ConflictChecker.check(t, among: [mOff, t], env: env).contains { $0.level == .replacesDisabled })
        let t2 = GestureBinding(trigger: three, action: .forward, device: .trackpad)
        XCTAssertTrue(ConflictChecker.check(t2, among: [t, t2], env: env).contains { $0.level == .duplicate })
        // Uygulamaya özel trackpad ataması genel fare atamasını ezmez.
        let app = GestureBinding(trigger: three, action: .back, appBundleID: "com.x", device: .trackpad)
        XCTAssertFalse(ConflictChecker.check(app, among: [m, app], env: env).contains { $0.level == .shadows })
    }

    func testMigrationsStayWithinDevice() {
        // Trackpad ataması temel olarak işaretlenmez.
        let t = GestureBinding(trigger: Trigger(kind: .press, fingers: 2), action: .middleClick, device: .trackpad)
        XCTAssertNil(BindingMigrations.tagBuiltIns([t])[0].builtInKey)
        // Aynı tetikli trackpad ataması fare temel atamasının eklenmesini engellemez.
        let pinchPad = GestureBinding(trigger: Trigger(kind: .pinch, fingers: 2), action: .zoom(style: .gesture, modifiers: []),
                                      device: .trackpad)
        let added = BindingMigrations.addMissingBuiltIns([pinchPad])
        XCTAssertEqual(added.filter { $0.builtInKey == "pinch" }.map(\.device), [.magicMouse])
        // Farklı aygıttaki ikiz kopyayı silmez.
        let off = GestureBinding(trigger: three, action: .middleClick, enabled: false)
        let onPad = GestureBinding(trigger: three, action: .middleClick, device: .trackpad)
        XCTAssertEqual(BindingMigrations.collapseRedundantDisabledCopies([off, onPad]).count, 2)
        let four = GestureBinding(trigger: Trigger(kind: .press, fingers: 4), action: .middleClick)
        XCTAssertEqual(BindingMigrations.collapseRedundantFourFinger([onPad, four]).count, 2)
        // Varsayılanlar yalnız fare.
        XCTAssertTrue(DefaultBindings.from(legacy: LegacyFlags(zoneClick: true, twoFingerClick: true, threeFingerClick: true,
                                                               threeFingerTap: true, fnDrag: true))
            .allSatisfy { $0.device == .magicMouse })
    }

    // MARK: Aygıt sınıflaması

    func testMultitouchFamilyKind() {
        XCTAssertEqual(MultitouchFamily.kind(familyID: 112, isBuiltIn: false), .magicMouse)
        XCTAssertEqual(MultitouchFamily.kind(familyID: 113, isBuiltIn: false), .magicMouse)
        XCTAssertEqual(MultitouchFamily.kind(familyID: 127, isBuiltIn: false), .magicMouse)
        // Dahili her zaman trackpad (aile ne olursa olsun).
        XCTAssertEqual(MultitouchFamily.kind(familyID: 176, isBuiltIn: true), .trackpad)
        XCTAssertEqual(MultitouchFamily.kind(familyID: 112, isBuiltIn: true), .trackpad)
        // Dahili olmayan ve aralık dışı: harici Magic Trackpad.
        XCTAssertEqual(MultitouchFamily.kind(familyID: 128, isBuiltIn: false), .trackpad)
        XCTAssertEqual(MultitouchFamily.kind(familyID: 111, isBuiltIn: false), .trackpad)
        // Aile okunamadı, dahili değil: köprü fare sayar; trackpad sayılmaz.
        XCTAssertNil(MultitouchFamily.kind(familyID: -1, isBuiltIn: false))
    }

    func testDevicePresence() {
        XCTAssertFalse(DevicePresence.none.isPresent(.magicMouse))
        XCTAssertFalse(DevicePresence.none.isPresent(.trackpad))
        // "aile 176 (dahili), aile 113, aile 112 (fare)" gibi bir tarama: 1 fare başlatıldı.
        let p = DevicePresence(startedMice: 1, devices: [(176, true), (113, false), (112, false)])
        XCTAssertEqual(p.mice, 1)
        XCTAssertEqual(p.trackpads, 1)
        XCTAssertTrue(p.builtInTrackpad)
        XCTAssertTrue(p.isPresent(.magicMouse))
        XCTAssertTrue(p.isPresent(.trackpad))
        // Trackpad'siz Mac mini: trackpad pasif.
        // Bu MacBook'ta görülen durum: iki dahili aygıt tek trackpad sayılır.
        let macbook = DevicePresence(startedMice: 1, devices: [(176, true), (113, true), (112, false)])
        XCTAssertEqual(macbook.trackpads, 1)
        XCTAssertTrue(macbook.builtInTrackpad)

        let mini = DevicePresence(startedMice: 1, devices: [(112, false)])
        XCTAssertFalse(mini.isPresent(.trackpad))
        // Harici Magic Trackpad: dahili değil.
        let ext = DevicePresence(startedMice: 0, devices: [(128, false)])
        XCTAssertEqual(ext.trackpads, 1)
        XCTAssertFalse(ext.builtInTrackpad)
        XCTAssertFalse(ext.isPresent(.magicMouse))
        // Framework yüklenemedi (-1): fare yok.
        XCTAssertEqual(DevicePresence(startedMice: -1, devices: []).mice, 0)
    }
}

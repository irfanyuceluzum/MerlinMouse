import XCTest
@testable import MerlinCore

final class BuiltInBindingTests: XCTestCase {
    private let env = ConflictEnvironment()

    private func plain(_ t: Trigger, _ action: GestureAction = .middleClick, enabled: Bool = true,
                       scope: String? = nil) -> GestureBinding {
        GestureBinding(trigger: t.normalized, action: action, enabled: enabled, appBundleID: scope)
    }

    func testFromLegacyAssignsKeysInOrder() {
        let list = DefaultBindings.from(legacy: LegacyFlags(zoneClick: true, twoFingerClick: false,
                                                            threeFingerClick: true, threeFingerTap: false, fnDrag: true))
        XCTAssertEqual(list.map(\.builtInKey), ["zone-center", "two-finger", "three-finger", "three-finger-tap", "fn"])
        XCTAssertEqual(list.map(\.enabled), [true, false, true, false, true])
        XCTAssertTrue(list.allSatisfy { $0.isBuiltIn && $0.action == .middleClick && $0.appBundleID == nil })
        // Eski bayraklar ilk beş tanıma karşılık gelir; sonradan eklenen pinch göçle gelir.
        XCTAssertEqual(DefaultBindings.definitions.prefix(5).map(\.key), list.map { $0.builtInKey! })
    }

    func testPinchDefinition() {
        let d = DefaultBindings.definitions.last
        XCTAssertEqual(d?.key, "pinch")
        XCTAssertEqual(d?.trigger, Trigger(kind: .pinch, fingers: 2).normalized)
        XCTAssertEqual(d?.action, .zoom(style: .gesture, modifiers: []))
        XCTAssertEqual(d?.title, "İki parmakla çimdikle")
    }

    func testResetToDefault() {
        let def = DefaultBindings.definitions[0]
        var b = GestureBinding(trigger: Trigger(kind: .tap, fingers: 2), action: .back, enabled: false,
                               appBundleID: "com.x", builtInKey: "zone-center")
        let id = b.id
        b = DefaultBindings.resetToDefault(b)
        XCTAssertEqual(b.trigger, def.trigger)
        XCTAssertEqual(b.action, def.action)
        XCTAssertEqual(b.id, id)
        XCTAssertFalse(b.enabled)
        XCTAssertEqual(b.appBundleID, "com.x")
        let user = plain(Trigger(kind: .tap, fingers: 2), .back)
        XCTAssertEqual(DefaultBindings.resetToDefault(user), user)
    }

    func testTagBuiltIns() {
        let center = Trigger(kind: .press, fingers: 1, zone: .center)
        let changed = plain(center, .back)
        XCTAssertEqual(BindingMigrations.tagBuiltIns([changed])[0].builtInKey, "zone-center")

        // Açık olan tercih edilir.
        let off = plain(Trigger(kind: .press, fingers: 3), enabled: false)
        let on = plain(Trigger(kind: .press, fingers: 3))
        let out = BindingMigrations.tagBuiltIns([off, on])
        XCTAssertNil(out[0].builtInKey)
        XCTAssertEqual(out[1].builtInKey, "three-finger")
        // Hepsi kapalıysa ilki.
        let off2 = plain(Trigger(kind: .press, fingers: 3), enabled: false)
        XCTAssertEqual(BindingMigrations.tagBuiltIns([off, off2]).map(\.builtInKey), ["three-finger", nil])

        // Uygulama kapsamlıya verilmez; eşleşme yoksa ekleme olmaz.
        let app = plain(Trigger(kind: .press, fingers: 2), scope: "com.x")
        let r = BindingMigrations.tagBuiltIns([app])
        XCTAssertEqual(r.count, 1)
        XCTAssertNil(r[0].builtInKey)

        // İki kez çalıştırma aynı sonucu verir.
        let once = BindingMigrations.tagBuiltIns([changed, off, on, app])
        XCTAssertEqual(BindingMigrations.tagBuiltIns(once), once)
        // Zaten etiketliye dokunulmaz; aynı anahtar ikinci atamaya verilmez.
        let pre = GestureBinding(trigger: center.normalized, action: .back, builtInKey: "zone-center")
        XCTAssertNil(BindingMigrations.tagBuiltIns([pre, plain(center)])[1].builtInKey)
    }

    func testRemove() {
        let built = GestureBinding(trigger: Trigger(kind: .press, fingers: 2).normalized, action: .middleClick,
                                   builtInKey: "two-finger")
        let user = plain(Trigger(kind: .tap, fingers: 2))
        XCTAssertEqual(BindingSetOps.remove(built.id, in: [built, user]), [built, user])
        XCTAssertEqual(BindingSetOps.remove(user.id, in: [built, user]), [built])
    }

    func testUpsertKeepsDisabledBuiltInRival() {
        let t = Trigger(kind: .press, fingers: 3)
        let built = GestureBinding(trigger: t.normalized, action: .middleClick, enabled: false, builtInKey: "three-finger")
        let n = plain(t, .back)
        let out = BindingSetOps.upsert(n, in: [built])
        XCTAssertEqual(out.map(\.id), [built.id, n.id])
        XCTAssertFalse(out[0].enabled)
        // Açık built-in rakip kapatılır, silinmez.
        let onBuilt = GestureBinding(trigger: t.normalized, action: .middleClick, builtInKey: "three-finger")
        let out2 = BindingSetOps.upsert(n, in: [onBuilt])
        XCTAssertEqual(out2.count, 2)
        XCTAssertFalse(out2[0].enabled)
    }

    func testBuiltInRivalNotice() {
        let t = Trigger(kind: .press, fingers: 3)
        let built = GestureBinding(trigger: t.normalized, action: .middleClick, enabled: false, builtInKey: "three-finger")
        let n = plain(t, .back)
        let conflicts = ConflictChecker.check(n, among: [built, n], env: env)
        let c = conflicts.first { $0.level == .replacesDisabled }
        XCTAssertEqual(c?.detail, "Bu hareketin kapalı bir temel ataması var; kaydedersen yeni atama çalışır, temel atama kapalı kalır.")
        XCTAssertNil(BindingValidation.removalNotice(conflicts: conflicts))
        // Eklenen kapalı rakip hâlâ sayılır.
        let off = plain(t, enabled: false)
        XCTAssertNotNil(BindingValidation.removalNotice(conflicts: ConflictChecker.check(n, among: [off, n], env: env)))
    }

    func testOldJSONWithoutBuiltInKeyDecodes() throws {
        let b = plain(Trigger(kind: .press, fingers: 2))
        var dict = try JSONSerialization.jsonObject(with: JSONEncoder().encode(b)) as! [String: Any]
        XCTAssertNil(dict["builtInKey"])
        dict.removeValue(forKey: "builtInKey")
        let back = try JSONDecoder().decode(GestureBinding.self, from: JSONSerialization.data(withJSONObject: dict))
        XCTAssertEqual(back, b)
        XCTAssertNil(back.builtInKey)
        let tagged = GestureBinding(trigger: b.trigger, action: b.action, builtInKey: "fn")
        let rt = try JSONDecoder().decode(GestureBinding.self, from: JSONEncoder().encode(tagged))
        XCTAssertEqual(rt.builtInKey, "fn")
    }

    func testUpsertForcesBuiltInGlobalScope() {
        let b = GestureBinding(trigger: Trigger(kind: .press, fingers: 2).normalized, action: .back,
                               appBundleID: "com.x", appName: "X", builtInKey: "two-finger")
        let out = BindingSetOps.upsert(b, in: [])
        XCTAssertNil(out[0].appBundleID)
        XCTAssertNil(out[0].appName)
        let user = GestureBinding(trigger: b.trigger, action: .back, appBundleID: "com.x", appName: "X")
        XCTAssertEqual(BindingSetOps.upsert(user, in: [])[0].appBundleID, "com.x")
    }

    func testUpsertRemovesOpenNonBuiltInRival() {
        let t = Trigger(kind: .press, fingers: 3)
        let old = plain(t, .back), n = plain(t, .middleClick)
        let out = BindingSetOps.upsert(n, in: [old])
        XCTAssertEqual(out.map(\.id), [n.id])
        let built = GestureBinding(trigger: t.normalized, action: .back, builtInKey: "three-finger")
        let out2 = BindingSetOps.upsert(n, in: [built])
        XCTAssertEqual(out2.count, 2)
        XCTAssertFalse(out2.first { $0.id == built.id }!.enabled)
        let builtOff = GestureBinding(trigger: t.normalized, action: .back, enabled: false, builtInKey: "three-finger")
        XCTAssertEqual(BindingSetOps.upsert(n, in: [builtOff]).count, 2)
    }

    func testDuplicateDetailAndNotice() {
        let t = Trigger(kind: .press, fingers: 3)
        let old = plain(t, .back), n = plain(t)
        let c1 = ConflictChecker.check(n, among: [old, n], env: env).first { $0.level == .duplicate }
        XCTAssertEqual(c1?.detail, "Kaydedersen önceki '\(old.action.title)' ataması silinir ve yerine bu geçer.")
        XCTAssertEqual(BindingValidation.removalNotice(conflicts: ConflictChecker.check(n, among: [old, n], env: env)),
                       "Kaydedersen '\(old.action.title)' ataması silinir ve yerine bu geçer.")
        let built = GestureBinding(trigger: t.normalized, action: .back, builtInKey: "three-finger")
        let conflicts = ConflictChecker.check(n, among: [built, n], env: env)
        XCTAssertEqual(conflicts.first { $0.level == .duplicate }?.detail,
                       "Kaydedersen temel '\(built.action.title)' ataması kapatılır; istediğinde yeniden açabilirsin.")
        XCTAssertNil(BindingValidation.removalNotice(conflicts: conflicts))
    }
}

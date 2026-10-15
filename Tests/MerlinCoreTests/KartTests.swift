import XCTest
@testable import MerlinCore

final class KartTests: XCTestCase {
    private func b(_ t: Trigger, app: String? = nil, name: String? = nil, enabled: Bool = true,
                   action: GestureAction = .middleClick) -> GestureBinding {
        GestureBinding(trigger: t.normalized, action: action, enabled: enabled, appBundleID: app, appName: name)
    }

    // 1
    func testHasDoubleTapAppSpecific() {
        let dt = Trigger(kind: .doubleTap, fingers: 2)
        let idx = BindingIndex(bindings: [b(dt, app: "com.a")])
        XCTAssertTrue(idx.hasDoubleTap(fingers: 2, zone: .any, bundleID: "com.a"))
        XCTAssertFalse(idx.hasDoubleTap(fingers: 2, zone: .any, bundleID: "com.b"))
        XCTAssertFalse(idx.hasDoubleTap(fingers: 2, zone: .any, bundleID: nil))
        let g = BindingIndex(bindings: [b(dt)])
        XCTAssertTrue(g.hasDoubleTap(fingers: 2, zone: .any, bundleID: "com.b"))
        XCTAssertTrue(g.hasDoubleTap(fingers: 2, zone: .any, bundleID: nil))
    }

    // 2
    func testSingleFingerAnyFallback() {
        let tap = b(Trigger(kind: .tap, fingers: 1, zone: .any))
        let dbl = b(Trigger(kind: .doubleTap, fingers: 1, zone: .any), app: "com.a")
        let idx = BindingIndex(bindings: [tap, dbl])
        XCTAssertEqual(idx.match(Trigger(kind: .tap, fingers: 1, zone: .center), bundleID: nil)?.id, tap.id)
        XCTAssertEqual(idx.match(Trigger(kind: .doubleTap, fingers: 1, zone: .right), bundleID: "com.a")?.id, dbl.id)
        XCTAssertNil(idx.match(Trigger(kind: .doubleTap, fingers: 1, zone: .right), bundleID: nil))
        XCTAssertTrue(idx.hasDoubleTap(fingers: 1, zone: .left, bundleID: "com.a"))
        XCTAssertFalse(idx.hasDoubleTap(fingers: 1, zone: .left, bundleID: nil))
        // Kesin eşleşme önceliklidir.
        let exact = b(Trigger(kind: .tap, fingers: 1, zone: .center), action: .back)
        let idx2 = BindingIndex(bindings: [tap, exact])
        XCTAssertEqual(idx2.match(Trigger(kind: .tap, fingers: 1, zone: .center), bundleID: nil)?.id, exact.id)
    }

    // 3
    func testFourFingersFallBackToThree() {
        let press = b(Trigger(kind: .press, fingers: 3))
        let swipe = b(Trigger(kind: .swipe, fingers: 3, direction: .left))
        let idx = BindingIndex(bindings: [press, swipe])
        XCTAssertEqual(idx.match(Trigger(kind: .press, fingers: 4), bundleID: nil)?.id, press.id)
        XCTAssertEqual(idx.match(Trigger(kind: .swipe, fingers: 4, direction: .left), bundleID: nil)?.id, swipe.id)
        XCTAssertNil(idx.match(Trigger(kind: .swipe, fingers: 4, direction: .right), bundleID: nil))
        let four = b(Trigger(kind: .press, fingers: 4), action: .back)
        let idx2 = BindingIndex(bindings: [press, four])
        XCTAssertEqual(idx2.match(Trigger(kind: .press, fingers: 4), bundleID: nil)?.id, four.id)
    }

    // 4
    func testDisabledDoesNotDuplicate() {
        let t = Trigger(kind: .press, fingers: 2)
        let off = b(t, enabled: false)
        let new = b(t)
        let levels = ConflictChecker.check(new, among: [off, new], env: ConflictEnvironment()).map(\.level)
        XCTAssertFalse(levels.contains(.duplicate))
        let on = b(t)
        XCTAssertTrue(ConflictChecker.check(new, among: [on, new], env: ConflictEnvironment()).map(\.level).contains(.duplicate))
    }

    func testSetEnabledDisablesRivals() {
        let t = Trigger(kind: .press, fingers: 2)
        let a = b(t), c = b(t, enabled: false), app = b(t, app: "com.a"), other = b(Trigger(kind: .tap, fingers: 3))
        let out = BindingSetOps.setEnabled(c.id, true, in: [a, c, app, other])
        XCTAssertEqual(out.map(\.enabled), [false, true, true, true])
        let off = BindingSetOps.setEnabled(c.id, false, in: out)
        XCTAssertEqual(off.map(\.enabled), [false, false, true, true])
    }

    func testUpsertDisablesRivals() {
        let t = Trigger(kind: .press, fingers: 2)
        let a = b(t)
        let n = b(t)
        let out = BindingSetOps.upsert(n, in: [a])
        XCTAssertEqual(out.map(\.enabled), [false, true])
        var edited = out[1]; edited.enabled = false
        XCTAssertEqual(BindingSetOps.upsert(edited, in: out).map(\.enabled), [false, false])
    }

    // 5
    func testShadows() {
        let t = Trigger(kind: .press, fingers: 2)
        let g = b(t, action: .back)
        let app = b(t, app: "com.a", name: "Safari")
        let c = ConflictChecker.check(app, among: [g, app], env: ConflictEnvironment()).first { $0.level == .shadows }
        XCTAssertEqual(c?.title, "Genel atamanın yerine geçer")
        XCTAssertEqual(c?.detail, "Safari'de '\(g.action.title)' yerine bu çalışır.")
        XCTAssertFalse(ConflictLevel.shadows.blocksSave)
        let noName = b(t, app: "com.a")
        XCTAssertTrue(ConflictChecker.check(noName, among: [g, noName], env: ConflictEnvironment())
            .first { $0.level == .shadows }!.detail.hasPrefix("com.a'de"))
        let gOff = b(t, enabled: false)
        XCTAssertFalse(ConflictChecker.check(app, among: [gOff, app], env: ConflictEnvironment()).contains { $0.level == .shadows })
        XCTAssertFalse(ConflictChecker.check(g, among: [g, app], env: ConflictEnvironment()).contains { $0.level == .shadows })
    }

    // 6
    func testFirstFreeTrigger() {
        let env = ConflictEnvironment()
        XCTAssertEqual(TriggerOptions.firstFreeTrigger(among: [], scope: nil, env: env),
                       Trigger(kind: .press, fingers: 1, zone: .right).normalized)
        let taken = [b(Trigger(kind: .press, fingers: 1, zone: .right))]
        XCTAssertEqual(TriggerOptions.firstFreeTrigger(among: taken, scope: nil, env: env),
                       Trigger(kind: .press, fingers: 2).normalized)
        // macOS ikincil tıklama açık: sağ çakışmalı ama engellemez; çakışmasız aday tercih edilir.
        let two = ConflictEnvironment(mouseButtonMode: "TwoButton")
        XCTAssertEqual(TriggerOptions.firstFreeTrigger(among: [], scope: nil, env: two),
                       Trigger(kind: .press, fingers: 2).normalized)
        // BTT: press 2/3 çakışır; ilk tamamen temiz aday doubleTap 2 olmalı (macOS çift dokunma kapalı).
        let btt = ConflictEnvironment(mouseButtonMode: "TwoButton", bttRunning: true)
        XCTAssertEqual(TriggerOptions.firstFreeTrigger(among: [], scope: nil, env: btt),
                       Trigger(kind: .doubleTap, fingers: 2).normalized)
    }

    func testFirstFreeTriggerFallbacks() {
        let env = ConflictEnvironment(mouseButtonMode: "TwoButton", twoFingerDoubleTap: 1, bttRunning: true)
        var all: [GestureBinding] = []
        for t in [Trigger(kind: .tap, fingers: 3), Trigger(kind: .swipe, fingers: 3, direction: .up),
                  Trigger(kind: .swipe, fingers: 3, direction: .down), Trigger(kind: .swipe, fingers: 3, direction: .left),
                  Trigger(kind: .swipe, fingers: 3, direction: .right)] { all.append(b(t)) }
        // Hiçbiri tamamen temiz değil: ilk engellemeyen = press 1 right.
        XCTAssertEqual(TriggerOptions.firstFreeTrigger(among: all, scope: nil, env: env),
                       Trigger(kind: .press, fingers: 1, zone: .right).normalized)
        // Hepsi dolu ve engelli: press 3.
        for t in [Trigger(kind: .press, fingers: 1, zone: .right), Trigger(kind: .press, fingers: 2),
                  Trigger(kind: .press, fingers: 3), Trigger(kind: .doubleTap, fingers: 2),
                  Trigger(kind: .press, modifier: .option)] { all.append(b(t)) }
        XCTAssertEqual(TriggerOptions.firstFreeTrigger(among: all, scope: nil, env: env),
                       Trigger(kind: .press, fingers: 3))
    }

    // 7
    func testUnavailableZoneReason() {
        XCTAssertEqual(TriggerOptions.unavailableZoneReason(kind: .press, fingers: 1, modifier: .none),
                       "Sol bölgeye basmak normal sol tıklamadır; değiştirilemez.")
        XCTAssertEqual(TriggerOptions.unavailableZoneReason(kind: .tap, fingers: 1, modifier: .none),
                       "Tek parmakla dokunma fareyi tutarken kazara tetiklenir.")
        XCTAssertEqual(TriggerOptions.unavailableZoneReason(kind: .swipe, fingers: 2, modifier: .none),
                       "Bir ve iki parmakla kaydırma macOS kaydırmasıdır.")
        XCTAssertNil(TriggerOptions.unavailableZoneReason(kind: .swipe, fingers: 3, modifier: .none))
        XCTAssertNil(TriggerOptions.unavailableZoneReason(kind: .press, fingers: 2, modifier: .none))
        XCTAssertNil(TriggerOptions.unavailableZoneReason(kind: .doubleTap, fingers: 1, modifier: .none))
    }

    // 9
    func testProfilesPersist() throws {
        let old = #"{"version":1,"bindings":[]}"#
        XCTAssertEqual(try JSONDecoder().decode(BindingSet.self, from: Data(old.utf8)).profiles, [])
        let set = BindingSet(bindings: [b(Trigger(kind: .press, fingers: 2))],
                             profiles: [ProfileApp(bundleID: "com.a", name: "A")])
        let data = try JSONEncoder().encode(set)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"profiles\""))
        XCTAssertEqual(try JSONDecoder().decode(BindingSet.self, from: data), set)
    }

    // 10
    func testRecoveredBackupName() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let legacy = LegacyFlags(zoneClick: true, twoFingerClick: false, threeFingerClick: true,
                                 threeFingerTap: true, fnDrag: false)
        let store = BindingFileStore(directory: dir, legacy: { legacy }, log: { _ in })
        _ = store.load()
        XCTAssertNil(store.lastRecoveredBackupName)
        try Data("{bozuk".utf8).write(to: store.fileURL)
        _ = store.load()
        XCTAssertTrue(store.lastRecoveredBackupName?.hasPrefix("bindings.bozuk-") == true)
        _ = store.load()
        XCTAssertNil(store.lastRecoveredBackupName)
    }

    // 11
    func testPauseState() {
        let now = Date(timeIntervalSince1970: 1000)
        XCTAssertFalse(PauseState().isPaused(now: now))
        let p = PauseState.pausing(for: 60, from: now)
        XCTAssertEqual(p.pausedUntil, now.addingTimeInterval(60))
        XCTAssertTrue(p.isPaused(now: now.addingTimeInterval(59)))
        XCTAssertFalse(p.isPaused(now: now.addingTimeInterval(60)))
    }

    // Kapalı atamanın yerine geçme
    func testReplacesDisabledConflict() {
        let t = Trigger(kind: .tap, fingers: 3)
        let off = b(t, enabled: false, action: .back)
        let new = b(t)
        let env = ConflictEnvironment()
        let c = ConflictChecker.check(new, among: [off, new], env: env).first { $0.level == .replacesDisabled }
        XCTAssertEqual(c?.title, "Kapalı bir ataması var")
        XCTAssertEqual(c?.detail, "Bu hareket kapalı '\(off.action.title)' atamasına bağlı. Kaydedersen yeni atama onun yerine geçer.")
        XCTAssertFalse(ConflictLevel.replacesDisabled.blocksSave)
        // Açık rakip varsa duplicate ile birlikte üretilir.
        let on = b(t)
        let lv = ConflictChecker.check(new, among: [off, on, new], env: env).map(\.level)
        XCTAssertTrue(lv.contains(.duplicate))
        XCTAssertTrue(lv.contains(.replacesDisabled))
        // Farklı kapsamda yok.
        let app = b(t, app: "com.a")
        XCTAssertFalse(ConflictChecker.check(app, among: [off, app], env: env).contains { $0.level == .replacesDisabled })
    }

    func testUpsertRemovesDisabledRivals() {
        let t = Trigger(kind: .tap, fingers: 3)
        let off = b(t, enabled: false), on = b(t), offApp = b(t, app: "com.a", enabled: false)
        let n = b(t)
        let out = BindingSetOps.upsert(n, in: [off, on, offApp])
        XCTAssertEqual(out.map(\.id), [on.id, offApp.id, n.id])
        XCTAssertEqual(out.map(\.enabled), [false, false, true])
        // Kapalı kayıt hiçbir şey kaldırmaz.
        var closed = b(t); closed.enabled = false
        XCTAssertEqual(BindingSetOps.upsert(closed, in: [off]).count, 2)
    }

    func testFirstFreeTriggerSkipsReplacesDisabled() {
        let env = ConflictEnvironment(mouseButtonMode: "TwoButton", twoFingerDoubleTap: 1, bttRunning: true)
        var all: [GestureBinding] = []
        // press 1 right, press 2, press 3, doubleTap 2 çakışmalı/dolu; tap 3 kapalı atamalı.
        for t in [Trigger(kind: .press, fingers: 1, zone: .right), Trigger(kind: .press, fingers: 2),
                  Trigger(kind: .press, fingers: 3), Trigger(kind: .doubleTap, fingers: 2)] { all.append(b(t)) }
        all.append(b(Trigger(kind: .tap, fingers: 3), enabled: false))
        XCTAssertEqual(TriggerOptions.firstFreeTrigger(among: all, scope: nil, env: env),
                       Trigger(kind: .swipe, fingers: 3, direction: .up).normalized)
        // Yalnız kapalı atamalı aday kaldıysa onu seçebilir.
        let only = ConflictEnvironment()
        var offAll = [b(Trigger(kind: .press, fingers: 1, zone: .right)), b(Trigger(kind: .press, fingers: 2)),
                      b(Trigger(kind: .press, fingers: 3)), b(Trigger(kind: .doubleTap, fingers: 2)),
                      b(Trigger(kind: .press, modifier: .option))]
        for d in [SwipeDirection.up, .down, .left, .right] { offAll.append(b(Trigger(kind: .swipe, fingers: 3, direction: d))) }
        offAll.append(b(Trigger(kind: .tap, fingers: 3), enabled: false))
        XCTAssertEqual(TriggerOptions.firstFreeTrigger(among: offAll, scope: nil, env: only),
                       Trigger(kind: .tap, fingers: 3).normalized)
    }

    func testReplacesDisabledStatusAndHeaviest() {
        let c = Conflict(level: .replacesDisabled, title: "", detail: "")
        XCTAssertEqual(BindingStatus.kind(enabled: true, conflicts: [c]), .replacesDisabled)
        XCTAssertEqual(BindingStatus.kind(enabled: false, conflicts: [c]), .disabled)
        XCTAssertEqual(BindingValidation.heaviest([c])?.level, .replacesDisabled)
        XCTAssertEqual(BindingValidation.saveMode(conflicts: [c], missing: nil), .direct)
    }

    func testRemovalNotice() {
        let t = Trigger(kind: .press, fingers: 2)
        let off = b(t, enabled: false, action: .back)
        let new = b(t)
        let btt = ConflictEnvironment(bttRunning: true)
        let mac = ConflictEnvironment(mouseButtonMode: "TwoButton")
        func notice(_ among: [GestureBinding], _ env: ConflictEnvironment) -> String? {
            BindingValidation.removalNotice(conflicts: ConflictChecker.check(new, among: among + [new], env: env))
        }
        XCTAssertEqual(notice([off], btt), "Kaydedersen kapalı '\(off.action.title)' ataması silinir ve yerine bu geçer.")
        XCTAssertNotNil(notice([off], ConflictEnvironment(twoFingerDoubleTap: 1)))
        let t1 = Trigger(kind: .press, fingers: 1, zone: .right)
        let off1 = b(t1, enabled: false), new1 = b(t1)
        XCTAssertNotNil(BindingValidation.removalNotice(conflicts: ConflictChecker.check(new1, among: [off1, new1], env: mac)))
        XCTAssertNotNil(notice([off, b(t)], ConflictEnvironment()))
        XCTAssertNil(notice([], btt))
        XCTAssertEqual(notice([off, b(t, enabled: false)], ConflictEnvironment()), "Kaydedersen kapalı 2 atama silinir ve yerine bu geçer.")
    }
}

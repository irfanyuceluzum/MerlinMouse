import XCTest
@testable import MerlinCore

/// Kart 33: trackpad temel atamaları, aygıt farkındalığı, seçenekler, çakışmalar, katalog, tıklama kaynağı ve akış seçimi.
final class TrackpadInputTests: XCTestCase {
    private let env = ConflictEnvironment()
    private let tap3 = Trigger(kind: .tap, fingers: 3).normalized
    private let press3 = Trigger(kind: .press, fingers: 3).normalized

    private func only(_ list: [GestureBinding], _ key: String) -> [GestureBinding] {
        list.filter { $0.builtInKey == key }
    }

    // MARK: Temel tanımlar ve göç

    func testTrackpadDefinitions() throws {
        let tap = try XCTUnwrap(DefaultBindings.definitions.first { $0.key == "tp-tap3" })
        let press = try XCTUnwrap(DefaultBindings.definitions.first { $0.key == "tp-press3" })
        XCTAssertEqual(tap.trigger, tap3)
        XCTAssertEqual(press.trigger, press3)
        XCTAssertEqual(tap.action, .middleClick)
        XCTAssertEqual(press.action, .middleClick)
        XCTAssertEqual(tap.device, .trackpad)
        XCTAssertEqual(press.device, .trackpad)
        XCTAssertFalse(tap.defaultEnabled)
        XCTAssertFalse(press.defaultEnabled)
        XCTAssertEqual(tap.title, "Üç parmakla dokun")
        XCTAssertEqual(press.title, "Üç parmakla bas")
        // Diğer tüm tanımlar fare.
        XCTAssertTrue(DefaultBindings.definitions.filter { !$0.key.hasPrefix("tp-") }.allSatisfy { $0.device == .magicMouse })
    }

    func testAddMissingAddsTrackpadOnceDisabled() {
        let old = DefaultBindings.from(legacy: LegacyFlags(zoneClick: true, twoFingerClick: true, threeFingerClick: true,
                                                           threeFingerTap: true, fnDrag: true))
        let once = BindingMigrations.addMissingBuiltIns(BindingMigrations.tagBuiltIns(old))
        for key in ["tp-tap3", "tp-press3"] {
            let b = only(once, key)
            XCTAssertEqual(b.count, 1, key)
            XCTAssertEqual(b.first?.device, .trackpad, key)
            XCTAssertEqual(b.first?.enabled, false, key)
            XCTAssertNil(b.first?.appBundleID, key)
        }
        // Aynı tetikli fare temelleri (three-finger, three-finger-tap) trackpad eklenmesini engellemez.
        XCTAssertEqual(only(once, "three-finger").map(\.device), [.magicMouse])
        XCTAssertEqual(only(once, "three-finger-tap").map(\.device), [.magicMouse])
        // Fare atamaları değişmez.
        XCTAssertEqual(Array(once.prefix(old.count)), BindingMigrations.tagBuiltIns(old))
        // Yinelenmez.
        XCTAssertEqual(BindingMigrations.addMissingBuiltIns(once), once)
        XCTAssertEqual(BindingMigrations.addMissingBuiltIns(BindingMigrations.tagBuiltIns(once)), once)
    }

    func testUserTrackpadBindingIsTaggedNotDuplicated() {
        // Anahtarsız genel trackpad ataması: tagBuiltIns işaretler, ekleme yapılmaz; eylem ve açık durumu korunur.
        let mine = GestureBinding(trigger: tap3, action: .back, enabled: true, device: .trackpad)
        let out = BindingMigrations.addMissingBuiltIns(BindingMigrations.tagBuiltIns([mine]))
        XCTAssertEqual(only(out, "tp-tap3").count, 1)
        XCTAssertEqual(only(out, "tp-tap3").first?.id, mine.id)
        XCTAssertEqual(only(out, "tp-tap3").first?.action, .back)
        XCTAssertEqual(only(out, "tp-tap3").first?.enabled, true)
        // Fare ataması trackpad temeli olarak işaretlenmez.
        let mouse = GestureBinding(trigger: tap3, action: .back)
        XCTAssertNotEqual(BindingMigrations.tagBuiltIns([mouse])[0].builtInKey, "tp-tap3")
    }

    func testResetToDefaultKeepsDevice() {
        let tp = GestureBinding(trigger: Trigger(kind: .doubleTap, fingers: 4), action: .back, enabled: true,
                                builtInKey: "tp-press3", device: .trackpad)
        let r = DefaultBindings.resetToDefault(tp)
        XCTAssertEqual(r.device, .trackpad)
        XCTAssertEqual(r.trigger, press3)
        XCTAssertEqual(r.action, .middleClick)
        XCTAssertTrue(r.enabled)
        XCTAssertEqual(r.id, tp.id)
        let mouse = GestureBinding(trigger: tap3, action: .back, builtInKey: "three-finger", device: .trackpad)
        XCTAssertEqual(DefaultBindings.resetToDefault(mouse).device, .magicMouse)
    }

    /// Eski sürümün çözücüsünün taklidi: `trigger` zorunlu.
    private struct LegacyBinding: Decodable {
        var id: UUID
        var trigger: Trigger
        var action: GestureAction
        var enabled: Bool
    }

    func testOldVersionCannotDecodeTrackpadBuiltIns() throws {
        let added = BindingMigrations.addMissingBuiltIns([])
        for b in added {
            let data = try JSONEncoder().encode(b)
            if b.device == .trackpad {
                XCTAssertThrowsError(try JSONDecoder().decode(LegacyBinding.self, from: data), b.builtInKey ?? "")
            } else {
                XCTAssertNoThrow(try JSONDecoder().decode(LegacyBinding.self, from: data))
            }
        }
        // Yeni sürüm iki aygıtı da geri okur.
        let back = try JSONDecoder().decode(BindingSet.self, from: JSONEncoder().encode(BindingSet(bindings: added)))
        XCTAssertEqual(back.bindings, added)
    }

    // MARK: Aygıt farkındalığı

    func testIndexIgnoresDisabledTrackpadBuiltIns() {
        let all = BindingMigrations.addMissingBuiltIns(DefaultBindings.from(legacy: LegacyFlags(
            zoneClick: true, twoFingerClick: true, threeFingerClick: true, threeFingerTap: true, fnDrag: true)))
        let idx = BindingIndex(bindings: all)
        // Kapalıyken trackpad'de hiçbir eşleşme yok: olaylar değişmez.
        XCTAssertNil(idx.match(press3, bundleID: nil, device: .trackpad))
        XCTAssertNil(idx.match(tap3, bundleID: nil, device: .trackpad))
        XCTAssertNil(idx.match(Trigger(kind: .press, fingers: 0, modifier: .fn), bundleID: nil, device: .trackpad))
        XCTAssertEqual(idx.match(press3, bundleID: nil)?.builtInKey, "three-finger")
        // Açılınca yalnız trackpad eşleşir; 4 parmak 3'e düşer.
        let on = all.map { b -> GestureBinding in
            var c = b
            if c.device == .trackpad { c.enabled = true }
            return c
        }
        let idx2 = BindingIndex(bindings: on)
        XCTAssertEqual(idx2.match(press3, bundleID: nil, device: .trackpad)?.builtInKey, "tp-press3")
        XCTAssertEqual(idx2.match(Trigger(kind: .press, fingers: 4), bundleID: nil, device: .trackpad)?.builtInKey, "tp-press3")
        XCTAssertEqual(idx2.match(tap3, bundleID: nil, device: .trackpad)?.builtInKey, "tp-tap3")
        XCTAssertEqual(idx2.match(press3, bundleID: nil)?.builtInKey, "three-finger")
    }

    func testOpsKeepDevicesApart() {
        let mouseBuilt = GestureBinding(trigger: press3, action: .middleClick, builtInKey: "three-finger")
        let padBuilt = GestureBinding(trigger: press3, action: .middleClick, enabled: true, builtInKey: "tp-press3",
                                      device: .trackpad)
        // Fare ataması açılınca trackpad ataması kapanmaz; tersi de.
        let mouseNew = GestureBinding(trigger: press3, action: .back)
        let a = BindingSetOps.upsert(mouseNew, in: [mouseBuilt, padBuilt])
        XCTAssertEqual(a.first { $0.id == padBuilt.id }?.enabled, true)
        XCTAssertEqual(a.first { $0.id == mouseBuilt.id }?.enabled, false)
        let padNew = GestureBinding(trigger: press3, action: .back, device: .trackpad)
        let b = BindingSetOps.upsert(padNew, in: [mouseBuilt, padBuilt])
        XCTAssertEqual(b.first { $0.id == mouseBuilt.id }?.enabled, true)
        XCTAssertEqual(b.first { $0.id == padBuilt.id }?.enabled, false)
        // setEnabled de aygıt içinde kalır.
        let mouseUser = GestureBinding(trigger: tap3, action: .back)
        let padOff = GestureBinding(trigger: tap3, action: .middleClick, enabled: false, builtInKey: "tp-tap3",
                                    device: .trackpad)
        let c = BindingSetOps.setEnabled(padOff.id, true, in: [mouseUser, padOff])
        XCTAssertEqual(c.map(\.enabled), [true, true])
        // Açık ve kapalı fare rakibi, trackpad ataması kaydedilince silinmez.
        let mouseOff = GestureBinding(trigger: tap3, action: .forward, enabled: false)
        let padUser = GestureBinding(trigger: tap3, action: .back, device: .trackpad)
        XCTAssertEqual(BindingSetOps.upsert(padUser, in: [mouseUser, mouseOff]).count, 3)
        // Aynı aygıtta açık eklenen rakip kaldırılır.
        let padOld = GestureBinding(trigger: tap3, action: .forward, device: .trackpad)
        XCTAssertEqual(BindingSetOps.upsert(padUser, in: [padOld]).map(\.id), [padUser.id])
        // Trackpad temeli silinemez.
        XCTAssertEqual(BindingSetOps.remove(padBuilt.id, in: [padBuilt]), [padBuilt])
    }

    func testPresetIgnoresTrackpadBindings() throws {
        let p = try XCTUnwrap(AppPresets.preset(id: "blender"))
        let id = "org.blenderfoundation.blender"
        let pad = GestureBinding(trigger: Trigger(kind: .press, fingers: 2), action: .back, appBundleID: id,
                                 appName: "Blender", device: .trackpad)
        let r = AppPresets.apply(p, bundleID: id, appName: "Blender", to: BindingSet(bindings: [pad]))
        XCTAssertEqual(r.added, 3)
        XCTAssertEqual(r.skipped, 0)
        XCTAssertTrue(r.set.bindings.dropFirst().allSatisfy { $0.device == .magicMouse })
        XCTAssertEqual(r.set.bindings.first, pad)
    }

    // MARK: Seçenekler

    func testTriggerOptionsForTrackpad() {
        XCTAssertEqual(TriggerOptions.kinds(device: .trackpad), [.tap, .press, .doubleTap])
        XCTAssertEqual(TriggerOptions.kinds(device: .magicMouse), TriggerOptions.editableKinds)
        for k in GestureKind.allCases {
            let fingers = TriggerOptions.fingerChoices(kind: k, device: .trackpad)
            let expected: [Int] = k == .press ? [1, 3, 4] : ([.tap, .doubleTap].contains(k) ? [3, 4] : [])
            XCTAssertEqual(fingers, expected, "\(k)")
            XCTAssertEqual(TriggerOptions.modifierChoices(kind: k, device: .trackpad), [.none], "\(k)")
            for f in 0...4 {
                for m in PressModifier.allCases {
                    // Bölge olarak yalnız tek parmak, tuşsuz basmada dört köşe.
                    let zones = TriggerOptions.zoneChoices(kind: k, fingers: f, modifier: m, device: .trackpad)
                    XCTAssertEqual(zones, k == .press && f == 1 && m == .none ? Zone.corners : [], "\(k) \(f) \(m)")
                    XCTAssertNil(TriggerOptions.unavailableZoneReason(kind: k, fingers: f, modifier: m, device: .trackpad))
                }
            }
        }
        // Köşesiz tek parmak basma yok: köşeye çekilir.
        XCTAssertEqual(TriggerOptions.sanitize(Trigger(kind: .press, fingers: 1, zone: .center, modifier: .fn), device: .trackpad),
                       Trigger(kind: .press, fingers: 1, zone: .cornerTopLeft))
        XCTAssertEqual(TriggerOptions.sanitize(Trigger(kind: .press, fingers: 2), device: .trackpad), press3)
        XCTAssertEqual(TriggerOptions.sanitize(Trigger(kind: .swipe, fingers: 4, direction: .left), device: .trackpad),
                       Trigger(kind: .tap, fingers: 4))
        XCTAssertEqual(TriggerOptions.sanitize(Trigger(kind: .doubleTap, fingers: 2, zone: .rear), device: .trackpad),
                       Trigger(kind: .doubleTap, fingers: 3))
        XCTAssertEqual(TriggerOptions.sanitize(Trigger(kind: .pinch, fingers: 2), device: .trackpad), tap3)
        // Fare varsayılanı aynen.
        XCTAssertEqual(TriggerOptions.sanitize(Trigger(kind: .press, fingers: 1, zone: .center, modifier: .fn)).modifier, .fn)
    }

    func testFirstFreeTriggerForTrackpad() {
        XCTAssertEqual(TriggerOptions.firstFreeTrigger(among: [], scope: nil, env: env, device: .trackpad), tap3)
        let taken = GestureBinding(trigger: tap3, action: .middleClick, device: .trackpad)
        XCTAssertEqual(TriggerOptions.firstFreeTrigger(among: [taken], scope: nil, env: env, device: .trackpad), press3)
        // Fare ataması trackpad önerisini etkilemez.
        let mouse = GestureBinding(trigger: tap3, action: .middleClick)
        XCTAssertEqual(TriggerOptions.firstFreeTrigger(among: [mouse], scope: nil, env: env, device: .trackpad), tap3)
        // Bak açıkken üç parmak dokunma çakışmalı: çakışmasız basma önerilir.
        let lookup = ConflictEnvironment(threeFingerTapLookup: true)
        XCTAssertEqual(TriggerOptions.firstFreeTrigger(among: [], scope: nil, env: lookup, device: .trackpad), press3)
    }

    // MARK: Çakışmalar

    private func levels(_ b: GestureBinding, _ e: ConflictEnvironment) -> [ConflictLevel] {
        ConflictChecker.check(b, among: [b], env: e).map(\.level)
    }

    func testTrackpadMacOSRules() {
        let lookup = ConflictEnvironment(threeFingerTapLookup: true)
        XCTAssertEqual(levels(GestureBinding(trigger: tap3, action: .middleClick, device: .trackpad), lookup), [.macOS])
        XCTAssertEqual(levels(GestureBinding(trigger: tap3, action: .middleClick, device: .trackpad), env), [])
        // Fare ataması trackpad kuralından etkilenmez.
        XCTAssertEqual(levels(GestureBinding(trigger: tap3, action: .middleClick), lookup), [])

        let drag = ConflictEnvironment(threeFingerDrag: true)
        let press = ConflictChecker.check(GestureBinding(trigger: press3, action: .middleClick, device: .trackpad),
                                          among: [], env: drag)
        XCTAssertEqual(press.map(\.level), [.macOS])
        XCTAssertEqual(press.first?.detail, "Üç parmakla sürükleme açık; üç parmakla basma onunla çakışır.")
        XCTAssertEqual(levels(GestureBinding(trigger: press3, action: .middleClick), drag), [])
        // Dört parmak basma üç parmak sürüklemeyle çakışmaz.
        XCTAssertEqual(levels(GestureBinding(trigger: Trigger(kind: .press, fingers: 4), action: .middleClick,
                                             device: .trackpad), drag), [])

        let swipes = ConflictEnvironment(threeFingerHorizSwipe: 2, threeFingerVertSwipe: 2)
        for d in SwipeDirection.allCases {
            let b = GestureBinding(trigger: Trigger(kind: .swipe, fingers: 3, direction: d), action: .back, device: .trackpad)
            XCTAssertEqual(levels(b, swipes), [.macOS], "\(d)")
            XCTAssertEqual(levels(GestureBinding(trigger: b.trigger, action: .back), swipes), [], "\(d)")
        }
        let horizOnly = ConflictEnvironment(threeFingerHorizSwipe: 1)
        XCTAssertEqual(levels(GestureBinding(trigger: Trigger(kind: .swipe, fingers: 3, direction: .up), action: .back,
                                             device: .trackpad), horizOnly), [])
        XCTAssertEqual(levels(GestureBinding(trigger: Trigger(kind: .swipe, fingers: 3, direction: .right), action: .back,
                                             device: .trackpad), horizOnly), [.macOS])
    }

    func testMouseRulesSkipTrackpad() {
        let busy = ConflictEnvironment(mouseButtonMode: "TwoButton", oneFingerDoubleTap: 1, twoFingerDoubleTap: 1,
                                       bttRunning: true)
        let pad = [
            GestureBinding(trigger: Trigger(kind: .press, fingers: 3), action: .middleClick, device: .trackpad),
            GestureBinding(trigger: Trigger(kind: .press, fingers: 2), action: .middleClick, device: .trackpad),
            GestureBinding(trigger: Trigger(kind: .doubleTap, fingers: 2), action: .back, device: .trackpad),
            GestureBinding(trigger: Trigger(kind: .doubleTap, fingers: 1), action: .back, device: .trackpad),
        ]
        for b in pad {
            XCTAssertFalse(levels(b, busy).contains { $0 == .macOS || $0 == .btt }, b.trigger.title)
        }
        // Fare kuralları farede aynen.
        XCTAssertTrue(levels(GestureBinding(trigger: press3, action: .middleClick), busy).contains(.btt))
        XCTAssertTrue(levels(GestureBinding(trigger: Trigger(kind: .doubleTap, fingers: 2), action: .back), busy).contains(.macOS))
    }

    // MARK: Trackpad sistem hareketleri

    func testTrackpadCatalogDefault() {
        let sections = TrackpadGestureCatalog.sections(env: env)
        XCTAssertEqual(sections.map(\.title), ["Dokunma ve tıklama", "Kaydırma ve yakınlaştırma", "Diğer hareketler",
                                               "Erişilebilirlik"])
        XCTAssertEqual(sections.map(\.rows.count), [4, 4, 4, 1])
        let rows = TrackpadGestureCatalog.rows(env: env)
        XCTAssertEqual(rows.map(\.status), [.off, .always, .off, .off, .always, .off, .off, .off, .off, .off, .off, .off, .off])
        XCTAssertEqual(rows.map(\.isConfigurable),
                       [false, false, true, true, false, false, false, false, true, true, false, false, true])
        XCTAssertEqual(rows[2].gesture, "Köşeden ikincil tıklama")
        XCTAssertEqual(rows[2].task, "İkincil tıklama")
        XCTAssertEqual(rows[3].gesture, "Üç parmakla dokunma")
        XCTAssertEqual(rows[12].gesture, "Üç parmakla sürükleme")
        XCTAssertEqual(TrackpadGestureCatalog.conflictCount(env: env), 0)
    }

    func testTrackpadCatalogBusy() {
        let busy = ConflictEnvironment(trackpadTapToClick: true, threeFingerTapLookup: true, trackpadPinch: true,
                                       trackpadSmartZoom: true, trackpadRotate: true, threeFingerHorizSwipe: 2,
                                       threeFingerVertSwipe: 2, notificationCenterSwipe: true, fiveFingerPinch: true,
                                       threeFingerDrag: true, trackpadCornerSecondaryClick: 2)
        let rows = TrackpadGestureCatalog.rows(env: busy)
        XCTAssertEqual(rows.map(\.status), [.on, .always, .on, .on, .always, .on, .on, .on, .on, .on, .on, .on, .on])
        XCTAssertEqual(rows[2].note, "Çakışır, atanırsa uyarı verilir")
        XCTAssertEqual(rows[3].note, "Çakışır, atanırsa uyarı verilir")
        XCTAssertEqual(TrackpadGestureCatalog.conflictCount(env: busy), 5)
        // Fare kataloğu trackpad alanlarından etkilenmez.
        XCTAssertEqual(SystemGestureCatalog.conflictCount(env: busy), 0)
    }

    // MARK: Tıklama kaynağı

    func testClickSource() {
        let now = 100.0
        XCTAssertNil(ClickSource.resolve(mouse: (0, now), trackpad: (0, now), now: now))
        XCTAssertEqual(ClickSource.resolve(mouse: (2, now - 0.01), trackpad: (0, now), now: now), .magicMouse)
        XCTAssertEqual(ClickSource.resolve(mouse: (0, now), trackpad: (3, now - 0.01), now: now), .trackpad)
        // İkisinde de parmak: son karesi yeni olan; eşitlikte fare.
        XCTAssertEqual(ClickSource.resolve(mouse: (2, now - 0.05), trackpad: (3, now - 0.01), now: now), .trackpad)
        XCTAssertEqual(ClickSource.resolve(mouse: (2, now - 0.01), trackpad: (3, now - 0.05), now: now), .magicMouse)
        XCTAssertEqual(ClickSource.resolve(mouse: (2, now - 0.02), trackpad: (3, now - 0.02), now: now), .magicMouse)
        // 0.25 sn'den eski kare parmak sayılmaz.
        XCTAssertEqual(ClickSource.resolve(mouse: (2, now - 0.3), trackpad: (3, now - 0.01), now: now), .trackpad)
        XCTAssertEqual(ClickSource.resolve(mouse: (2, now - 0.01), trackpad: (3, now - 0.26), now: now), .magicMouse)
        XCTAssertNil(ClickSource.resolve(mouse: (2, now - 0.3), trackpad: (3, now - 0.3), now: now))
        XCTAssertEqual(ClickSource.resolve(mouse: (0, 0), trackpad: (1, now - 0.25), now: now), .trackpad)
    }

    // MARK: Basış yönlendirme (fare dönüşümü kaybolmasın)

    func testRoutingWithoutTrackpadBindingsIsMouseOnly() {
        let now = 50.0
        // Trackpad ataması kapalı: kaynak ne olursa olsun yalnız bugünkü fare yolu.
        for pad in [(0, 0.0), (3, now - 0.01), (2, now)] as [(Int, Double)] {
            for mouse in [(0, 0.0), (2, now - 0.1), (3, now - 0.3)] as [(Int, Double)] {
                XCTAssertEqual(ClickRouting.route(trackpadBindingsActive: false, mouse: mouse, trackpad: pad, now: now),
                               [.magicMouse])
            }
        }
    }

    func testRoutingPalmOnTrackpadWhileClickingMouse() {
        let now = 50.0
        // Avuç trackpad'e değiyor (daha yeni kare), fareye tıklanıyor: önce trackpad, eşleşme yoksa fare.
        XCTAssertEqual(ClickRouting.route(trackpadBindingsActive: true, mouse: (2, now - 0.03),
                                          trackpad: (1, now - 0.01), now: now),
                       [.trackpad, .magicMouse])
        // Avuç değiyor, farede taze parmak yok: yalnız trackpad (eşleşmezse olay geçer; bugün de fare yolu boştu).
        XCTAssertEqual(ClickRouting.route(trackpadBindingsActive: true, mouse: (2, now - 0.4),
                                          trackpad: (1, now - 0.01), now: now),
                       [.trackpad])
    }

    func testRoutingBothFresh() {
        let now = 50.0
        XCTAssertEqual(ClickRouting.route(trackpadBindingsActive: true, mouse: (2, now - 0.01),
                                          trackpad: (3, now - 0.05), now: now),
                       [.magicMouse])
        XCTAssertEqual(ClickRouting.route(trackpadBindingsActive: true, mouse: (2, now - 0.05),
                                          trackpad: (3, now - 0.01), now: now),
                       [.trackpad, .magicMouse])
        // Eşitlikte fare.
        XCTAssertEqual(ClickRouting.route(trackpadBindingsActive: true, mouse: (2, now - 0.02),
                                          trackpad: (3, now - 0.02), now: now),
                       [.magicMouse])
        // Hiçbirinde taze parmak yok: fare yolu (bugünkü gibi).
        XCTAssertEqual(ClickRouting.route(trackpadBindingsActive: true, mouse: (0, 0), trackpad: (0, 0), now: now),
                       [.magicMouse])
    }

    func testIndexTrackpadPresenceQueries() {
        let off = GestureBinding(trigger: press3, action: .middleClick, enabled: false, builtInKey: "tp-press3",
                                 device: .trackpad)
        let mouse = GestureBinding(trigger: press3, action: .middleClick)
        XCTAssertFalse(BindingIndex(bindings: [off, mouse]).hasBindings(device: .trackpad, bundleID: nil))
        XCTAssertFalse(BindingIndex(bindings: [off, mouse]).hasAnyBinding(device: .trackpad))
        XCTAssertTrue(BindingIndex(bindings: [off, mouse]).hasAnyBinding(device: .magicMouse))
        // Yalnız bir uygulamaya özel trackpad ataması: o uygulama öndeyken var; herhangi kapsamda da var.
        let app = GestureBinding(trigger: tap3, action: .back, appBundleID: "com.x", device: .trackpad)
        let idx = BindingIndex(bindings: [off, mouse, app])
        XCTAssertTrue(idx.hasBindings(device: .trackpad, bundleID: "com.x"))
        XCTAssertFalse(idx.hasBindings(device: .trackpad, bundleID: "com.y"))
        XCTAssertFalse(idx.hasBindings(device: .trackpad, bundleID: nil))
        XCTAssertTrue(idx.hasAnyBinding(device: .trackpad))
        // Genel trackpad ataması her uygulamada.
        var on = off
        on.enabled = true
        XCTAssertTrue(BindingIndex(bindings: [on]).hasBindings(device: .trackpad, bundleID: "com.y"))
        XCTAssertTrue(BindingIndex(bindings: [on]).hasBindings(device: .trackpad, bundleID: nil))
    }

    /// Yüzeyin ortasında `n` parmak (köşe dışı).
    private func middle(_ n: Int) -> [TouchPoint] {
        (0..<n).map { TouchPoint(id: Int32($0), x: 0.4 + Float($0) * 0.05, y: 0.5) }
    }

    func testTrackpadPressCandidates() {
        let c = TrackpadCornerLayout.standard
        XCTAssertEqual(PressResolver.trackpadCandidates(fingers: [], fnDown: false, corners: c), [])
        XCTAssertEqual(PressResolver.trackpadCandidates(fingers: middle(1), fnDown: false, corners: c), [])
        XCTAssertEqual(PressResolver.trackpadCandidates(fingers: middle(3), fnDown: false, corners: c),
                       [Trigger(kind: .press, fingers: 3)])
        XCTAssertEqual(PressResolver.trackpadCandidates(fingers: middle(6), fnDown: false, corners: c),
                       [Trigger(kind: .press, fingers: 4)])
        XCTAssertEqual(PressResolver.trackpadCandidates(fingers: middle(3), fnDown: true, corners: c),
                       [Trigger(kind: .press, fingers: 0, modifier: .fn), Trigger(kind: .press, fingers: 3)])
    }

    // MARK: Trackpad akış seçimi

    func testStreamSelectorUsesOneDevice() {
        var s = TrackpadStreamSelector()
        XCTAssertEqual(s.lastFrame.touches, 0)
        // Boş kareler aygıt seçtirmez.
        XCTAssertFalse(s.accept(slot: 1, touches: 0, at: 0.00))
        XCTAssertNil(s.active)
        // Parmak karesi veren aygıt etkin olur; öteki aygıtın kareleri (boş ya da dolu) karışmaz.
        XCTAssertTrue(s.accept(slot: 0, touches: 3, at: 0.01))
        XCTAssertFalse(s.accept(slot: 1, touches: 0, at: 0.015))
        XCTAssertFalse(s.accept(slot: 1, touches: 2, at: 0.02))
        XCTAssertTrue(s.accept(slot: 0, touches: 3, at: 0.03))
        XCTAssertEqual(s.lastFrame.touches, 3)
        XCTAssertEqual(s.lastFrame.lastFrame, 0.03)
        // Etkin aygıtın boş karesi işlenir (parmak kalkışı).
        XCTAssertTrue(s.accept(slot: 0, touches: 0, at: 0.04))
        XCTAssertEqual(s.lastFrame.touches, 0)
        // Etkin aygıt boştayken diğer aygıt parmakla devralır.
        XCTAssertTrue(s.accept(slot: 1, touches: 2, at: 0.05))
        XCTAssertEqual(s.active, 1)
        XCTAssertFalse(s.accept(slot: 0, touches: 0, at: 0.06))
        // Etkin aygıt susarsa (eski kare) diğeri devralır.
        XCTAssertTrue(s.accept(slot: 0, touches: 1, at: 0.40))
        XCTAssertEqual(s.active, 0)
        s.reset()
        XCTAssertNil(s.active)
        XCTAssertEqual(s.lastFrame.touches, 0)
    }
}

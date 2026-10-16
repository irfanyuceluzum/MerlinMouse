import XCTest
@testable import MerlinCore

final class BindingMigrationsTests: XCTestCase {
    private func b(_ f: Int, _ action: GestureAction = .middleClick, scope: String? = nil,
                   enabled: Bool = true, kind: GestureKind = .press) -> GestureBinding {
        GestureBinding(trigger: Trigger(kind: kind, fingers: f), action: action, enabled: enabled, appBundleID: scope)
    }

    func testRemovesFourFingerWithThreeFingerTwin() {
        let three = b(3), four = b(4)
        let out = BindingMigrations.collapseRedundantFourFinger([three, four])
        XCTAssertEqual(out.map { $0.id }, [three.id])
    }

    func testKeepsWhenActionDiffers() {
        let list = [b(3), b(4, .back)]
        XCTAssertEqual(BindingMigrations.collapseRedundantFourFinger(list).count, 2)
    }

    func testKeepsWhenScopeDiffers() {
        let list = [b(3), b(4, scope: "com.x")]
        XCTAssertEqual(BindingMigrations.collapseRedundantFourFinger(list).count, 2)
    }

    func testKeepsWithoutTwinAndWhenEnabledDiffers() {
        XCTAssertEqual(BindingMigrations.collapseRedundantFourFinger([b(4)]).count, 1)
        XCTAssertEqual(BindingMigrations.collapseRedundantFourFinger([b(3, enabled: false), b(4)]).count, 2)
        XCTAssertEqual(BindingMigrations.collapseRedundantFourFinger([b(3), b(4, kind: .tap)]).count, 2)
    }

    func testCollapseDisabledCopies() {
        let on = b(3), off = b(3, enabled: false)
        XCTAssertEqual(BindingMigrations.collapseRedundantDisabledCopies([on, off]).map { $0.id }, [on.id])
        // Farklı eylem, farklı kapsam, açık eş yok: kalır.
        XCTAssertEqual(BindingMigrations.collapseRedundantDisabledCopies([on, b(3, .back, enabled: false)]).count, 2)
        XCTAssertEqual(BindingMigrations.collapseRedundantDisabledCopies([on, b(3, scope: "com.x", enabled: false)]).count, 2)
        XCTAssertEqual(BindingMigrations.collapseRedundantDisabledCopies([off]).count, 1)
        // Temel ise kalır.
        let built = GestureBinding(trigger: Trigger(kind: .press, fingers: 3), action: .middleClick, enabled: false, builtInKey: "three-finger")
        XCTAssertEqual(BindingMigrations.collapseRedundantDisabledCopies([on, built]).count, 2)
    }

    func testCollapseDisabledCopyWithBuiltInTwin() {
        let built = GestureBinding(trigger: Trigger(kind: .press, fingers: 3), action: .middleClick, enabled: false, builtInKey: "three-finger")
        let copy = b(3, enabled: false)
        XCTAssertEqual(BindingMigrations.collapseRedundantDisabledCopies([built, copy]).map { $0.id }, [built.id])
        let diff = b(3, .back, enabled: false)
        XCTAssertEqual(BindingMigrations.collapseRedundantDisabledCopies([built, diff]).count, 2)
    }

    private func only(_ list: [GestureBinding], _ key: String) -> [GestureBinding] {
        list.filter { $0.builtInKey == key }
    }

    func testAddMissingBuiltInsOnce() {
        let empty = BindingMigrations.addMissingBuiltIns([])
        XCTAssertEqual(empty.map(\.builtInKey), ["pinch", "edge-left", "edge-right", "tp-tap3", "tp-press3"])
        XCTAssertEqual(empty[0].trigger, Trigger(kind: .pinch, fingers: 2).normalized)
        XCTAssertEqual(empty[0].action, .zoom(style: .gesture, modifiers: []))
        XCTAssertTrue(empty[0].enabled)
        XCTAssertTrue(empty.allSatisfy { $0.appBundleID == nil })
        // Kenarlar kapalı eklenir.
        XCTAssertEqual(empty[1].trigger, Trigger(kind: .edgeSlide, zone: .leftEdge).normalized)
        XCTAssertEqual(empty[1].action, .volume)
        XCTAssertFalse(empty[1].enabled)
        XCTAssertEqual(empty[2].trigger, Trigger(kind: .edgeSlide, zone: .rightEdge).normalized)
        XCTAssertEqual(empty[2].action, .brightness)
        XCTAssertFalse(empty[2].enabled)

        let old = DefaultBindings.from(legacy: LegacyFlags(zoneClick: true, twoFingerClick: true,
                                                           threeFingerClick: true, threeFingerTap: false, fnDrag: true))
        let once = BindingMigrations.addMissingBuiltIns(old)
        XCTAssertEqual(once.count, old.count + 5)
        for key in ["pinch", "edge-left", "edge-right", "tp-tap3", "tp-press3"] {
            XCTAssertEqual(only(once, key).count, 1, key)
        }
        // İkinci çağrı yinelemez.
        XCTAssertEqual(BindingMigrations.addMissingBuiltIns(once), once)
    }

    func testAddMissingBuiltInsOnlyAddsEdgesToPinchFile() {
        // Çimdikleme göçünden geçmiş dosya: yalnız iki kenar eklenir.
        let pinch = GestureBinding(trigger: Trigger(kind: .pinch, fingers: 2), action: .zoom(style: .gesture, modifiers: []),
                                   builtInKey: "pinch")
        let out = BindingMigrations.addMissingBuiltIns([pinch])
        XCTAssertEqual(out.map(\.builtInKey), ["pinch", "edge-left", "edge-right", "tp-tap3", "tp-press3"])
        XCTAssertEqual(out[0], pinch)
    }

    func testAddMissingBuiltInsKeepsUserEdgeChoice() {
        // Kullanıcının açtığı kenar kapanmaz, eylemi de değişmez.
        let on = GestureBinding(trigger: Trigger(kind: .edgeSlide, zone: .leftEdge), action: .brightness,
                                enabled: true, builtInKey: "edge-left")
        let out = BindingMigrations.addMissingBuiltIns([on])
        XCTAssertEqual(only(out, "edge-left"), [on])
        XCTAssertEqual(only(out, "edge-right").count, 1)
        XCTAssertEqual(BindingMigrations.addMissingBuiltIns(out), out)
        // Anahtarsız genel kenar ataması varsa eklenmez; uygulamaya özel olan sayılmaz.
        let plain = GestureBinding(trigger: Trigger(kind: .edgeSlide, zone: .rightEdge), action: .volume)
        XCTAssertTrue(only(BindingMigrations.addMissingBuiltIns([plain]), "edge-right").isEmpty)
        let app = GestureBinding(trigger: Trigger(kind: .edgeSlide, zone: .rightEdge), action: .volume, appBundleID: "com.x")
        XCTAssertEqual(only(BindingMigrations.addMissingBuiltIns([app]), "edge-right").count, 1)
    }

    func testAddMissingBuiltInsKeepsUserPinchChoice() {
        // Kullanıcının kapattığı temel pinch aynen kalır.
        let off = GestureBinding(trigger: Trigger(kind: .pinch, fingers: 2), action: .zoom(style: .gesture, modifiers: []),
                                 enabled: false, builtInKey: "pinch")
        XCTAssertEqual(only(BindingMigrations.addMissingBuiltIns([off]), "pinch"), [off])
        // Anahtarsız pinch ataması: tagBuiltIns işaretler, ekleme yapılmaz.
        let plain = GestureBinding(trigger: Trigger(kind: .pinch, fingers: 2), action: .zoom(style: .gesture, modifiers: []))
        let tagged = BindingMigrations.addMissingBuiltIns(BindingMigrations.tagBuiltIns([plain]))
        XCTAssertEqual(tagged.filter { $0.trigger.normalized.kind == .pinch }.count, 1)
        XCTAssertEqual(tagged[0].builtInKey, "pinch")
        XCTAssertTrue(only(BindingMigrations.addMissingBuiltIns([plain]), "pinch").isEmpty)
        // Yalnız uygulamaya özel pinch varsa genel temel eklenir.
        let app = GestureBinding(trigger: Trigger(kind: .pinch, fingers: 2), action: .zoom(style: .wheel, modifiers: []),
                                 appBundleID: "com.x")
        XCTAssertEqual(only(BindingMigrations.addMissingBuiltIns([app]), "pinch").count, 1)
    }
}

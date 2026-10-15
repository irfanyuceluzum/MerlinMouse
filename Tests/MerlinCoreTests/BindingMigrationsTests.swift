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

    func testAddMissingPinchOnce() {
        let empty = BindingMigrations.addMissingPinch([])
        XCTAssertEqual(empty.count, 1)
        XCTAssertEqual(empty[0].builtInKey, "pinch")
        XCTAssertEqual(empty[0].trigger, Trigger(kind: .pinch, fingers: 2).normalized)
        XCTAssertEqual(empty[0].action, .zoom(style: .gesture, modifiers: []))
        XCTAssertTrue(empty[0].enabled)
        XCTAssertNil(empty[0].appBundleID)

        let old = DefaultBindings.from(legacy: LegacyFlags(zoneClick: true, twoFingerClick: true,
                                                           threeFingerClick: true, threeFingerTap: false, fnDrag: true))
        let once = BindingMigrations.addMissingPinch(old)
        XCTAssertEqual(once.count, old.count + 1)
        XCTAssertEqual(once.filter { $0.builtInKey == "pinch" }.count, 1)
        XCTAssertEqual(BindingMigrations.addMissingPinch(once), once)
    }

    func testAddMissingPinchKeepsUserChoice() {
        // Kullanıcının kapattığı temel pinch aynen kalır.
        let off = GestureBinding(trigger: Trigger(kind: .pinch, fingers: 2), action: .zoom(style: .gesture, modifiers: []),
                                 enabled: false, builtInKey: "pinch")
        XCTAssertEqual(BindingMigrations.addMissingPinch([off]), [off])
        // Anahtarsız pinch ataması: tagBuiltIns işaretler, ekleme yapılmaz.
        let plain = GestureBinding(trigger: Trigger(kind: .pinch, fingers: 2), action: .zoom(style: .gesture, modifiers: []))
        let tagged = BindingMigrations.addMissingPinch(BindingMigrations.tagBuiltIns([plain]))
        XCTAssertEqual(tagged.count, 1)
        XCTAssertEqual(tagged[0].builtInKey, "pinch")
        XCTAssertEqual(BindingMigrations.addMissingPinch([plain]), [plain])
        // Yalnız uygulamaya özel pinch varsa genel temel eklenir.
        let app = GestureBinding(trigger: Trigger(kind: .pinch, fingers: 2), action: .zoom(style: .wheel, modifiers: []),
                                 appBundleID: "com.x")
        XCTAssertEqual(BindingMigrations.addMissingPinch([app]).count, 2)
    }
}

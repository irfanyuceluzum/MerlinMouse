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
}

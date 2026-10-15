import XCTest
@testable import MerlinCore

final class BindingValidationTests: XCTestCase {
    private let env = ConflictEnvironment()

    func testReservedTriggerCannotSave() {
        let b = GestureBinding(trigger: Trigger(kind: .press, fingers: 1, zone: .left), action: .middleClick)
        let r = BindingValidation.evaluate(b, among: [], env: env)
        XCTAssertFalse(r.canSave)
        XCTAssertTrue(r.conflicts.contains { $0.level == .reserved })
        XCTAssertNil(r.missing)
    }

    func testEmptyShortcutMissing() {
        let b = GestureBinding(trigger: Trigger(kind: .press, fingers: 1, zone: .center),
                               action: .shortcut(KeyCombo(keyCode: 0, modifiers: [], display: "")))
        let r = BindingValidation.evaluate(b, among: [], env: env)
        XCTAssertEqual(r.missing, "Kısayol kaydedilmedi")
        XCTAssertFalse(r.canSave)
    }

    func testEmptyAppAndShortcutNameMissing() {
        let t = Trigger(kind: .press, fingers: 1, zone: .center)
        let app = GestureBinding(trigger: t, action: .openApp(path: "", name: ""))
        XCTAssertEqual(BindingValidation.evaluate(app, among: [], env: env).missing, "Uygulama seçilmedi")
        let sc = GestureBinding(trigger: t, action: .runShortcut(name: "  \n"))
        XCTAssertEqual(BindingValidation.evaluate(sc, among: [], env: env).missing, "Kestirme adı boş")
    }

    func testValidCenterPressCanSave() {
        let b = GestureBinding(trigger: Trigger(kind: .press, fingers: 1, zone: .center), action: .middleClick)
        let r = BindingValidation.evaluate(b, among: [], env: env)
        XCTAssertTrue(r.canSave)
        XCTAssertTrue(r.conflicts.isEmpty)
        XCTAssertNil(r.missing)
    }

    func testDuplicateCannotSave() {
        let t = Trigger(kind: .press, fingers: 1, zone: .center)
        let existing = GestureBinding(trigger: t, action: .middleClick)
        let b = GestureBinding(trigger: t, action: .back)
        let r = BindingValidation.evaluate(b, among: [existing], env: env)
        XCTAssertFalse(r.canSave)
        XCTAssertTrue(r.conflicts.contains { $0.level == .duplicate })
    }

    func testWarningLevelsDoNotBlock() {
        let b = GestureBinding(trigger: Trigger(kind: .press, fingers: 1, zone: .right), action: .back)
        let r = BindingValidation.evaluate(b, among: [], env: ConflictEnvironment(mouseButtonMode: "TwoButton"))
        XCTAssertTrue(r.conflicts.contains { $0.level == .macOS })
        XCTAssertTrue(r.canSave)
    }
}

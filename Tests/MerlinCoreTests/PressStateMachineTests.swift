import XCTest
@testable import MerlinCore

final class PressStateMachineTests: XCTestCase {
    private func binding(_ action: GestureAction) -> GestureBinding {
        GestureBinding(trigger: Trigger(kind: .press, fingers: 1, zone: .center), action: action)
    }

    func testDownWithoutBindingPasses() {
        var m = PressStateMachine()
        let r = m.mouseDown(.left, binding: nil)
        XCTAssertEqual(r.0, .pass)
        XCTAssertNil(r.runAction)
        XCTAssertEqual(m.mouseUp(.left), .pass)
    }

    func testMiddleClickLifecycle() {
        var m = PressStateMachine()
        let b = binding(.middleClick)
        let r = m.mouseDown(.left, binding: b)
        XCTAssertEqual(r.0, .convert(buttonNumber: 2))
        XCTAssertNil(r.runAction)
        XCTAssertTrue(m.isMiddleDragActive)
        XCTAssertFalse(m.didDrag)
        XCTAssertEqual(m.mouseDragged(.left), .convert(buttonNumber: 2))
        XCTAssertTrue(m.didDrag)
        XCTAssertEqual(m.binding, b)
        XCTAssertEqual(m.mouseUp(.left), .convert(buttonNumber: 2))
        XCTAssertFalse(m.isMiddleDragActive)
        XCTAssertEqual(m.mouseUp(.left), .pass)
        XCTAssertEqual(m.mouseDragged(.left), .pass)
    }

    func testBackAndForwardButtonNumbers() {
        var m = PressStateMachine()
        XCTAssertEqual(m.mouseDown(.right, binding: binding(.back)).0, .convert(buttonNumber: 3))
        XCTAssertFalse(m.isMiddleDragActive)
        XCTAssertEqual(m.mouseUp(.right), .convert(buttonNumber: 3))
        XCTAssertEqual(m.mouseDown(.right, binding: binding(.forward)).0, .convert(buttonNumber: 4))
        XCTAssertEqual(m.mouseUp(.right), .convert(buttonNumber: 4))
    }

    func testShortcutSwallowsAndAllowsNextSession() {
        var m = PressStateMachine()
        let action = GestureAction.system(.spotlight)
        let r = m.mouseDown(.left, binding: binding(action))
        XCTAssertEqual(r.0, .drop)
        XCTAssertEqual(r.runAction, action)
        XCTAssertFalse(m.isMiddleDragActive)
        XCTAssertEqual(m.mouseDragged(.left), .drop)
        XCTAssertFalse(m.didDrag)
        XCTAssertEqual(m.mouseUp(.left), .drop)
        XCTAssertEqual(m.mouseDown(.left, binding: binding(.middleClick)).0, .convert(buttonNumber: 2))
    }

    func testOtherSideEventsPass() {
        var m = PressStateMachine()
        _ = m.mouseDown(.left, binding: binding(.middleClick))
        XCTAssertEqual(m.mouseDown(.right, binding: binding(.middleClick)).0, .pass)
        XCTAssertEqual(m.mouseDragged(.right), .pass)
        XCTAssertEqual(m.mouseUp(.right), .pass)
        XCTAssertTrue(m.isMiddleDragActive)
    }

    func testSecondDownWhileActivePasses() {
        var m = PressStateMachine()
        _ = m.mouseDown(.left, binding: binding(.middleClick))
        let r = m.mouseDown(.left, binding: binding(.system(.spotlight)))
        XCTAssertEqual(r.0, .pass)
        XCTAssertNil(r.runAction)
    }
}

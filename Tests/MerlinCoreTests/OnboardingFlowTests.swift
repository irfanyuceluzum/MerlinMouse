import XCTest
@testable import MerlinCore

final class OnboardingFlowTests: XCTestCase {
    func testPermissionAdvancesWhenTrusted() {
        var f = OnboardingFlow()
        f.update(trusted: false, miceCount: 1, touchSeen: true, middleActionSeen: true)
        XCTAssertEqual(f.step, .permission)
        XCTAssertFalse(f.canAdvance)
        f.update(trusted: true, miceCount: 0, touchSeen: false, middleActionSeen: false)
        XCTAssertEqual(f.step, .recognizeMouse)
    }

    func testRecognizeNeedsMouseAndTouch() {
        var f = OnboardingFlow(step: .recognizeMouse)
        f.update(trusted: true, miceCount: 1, touchSeen: false, middleActionSeen: false)
        XCTAssertEqual(f.step, .recognizeMouse)
        f.update(trusted: true, miceCount: 0, touchSeen: true, middleActionSeen: false)
        XCTAssertEqual(f.step, .recognizeMouse)
        f.update(trusted: true, miceCount: 1, touchSeen: true, middleActionSeen: false)
        XCTAssertEqual(f.step, .firstGesture)
    }

    func testFirstGestureFinishes() {
        var f = OnboardingFlow(step: .firstGesture)
        f.update(trusted: true, miceCount: 1, touchSeen: true, middleActionSeen: false)
        XCTAssertEqual(f.step, .firstGesture)
        f.update(trusted: true, miceCount: 1, touchSeen: true, middleActionSeen: true)
        XCTAssertEqual(f.step, .done)
        XCTAssertTrue(f.isFinished)
        XCTAssertFalse(f.canAdvance)
    }

    func testOneStepPerUpdate() {
        var f = OnboardingFlow()
        f.update(trusted: true, miceCount: 1, touchSeen: true, middleActionSeen: true)
        XCTAssertEqual(f.step, .recognizeMouse)
    }

    func testManualNavigation() {
        var f = OnboardingFlow()
        f.next(); XCTAssertEqual(f.step, .recognizeMouse)
        f.back(); XCTAssertEqual(f.step, .permission)
        f.back(); XCTAssertEqual(f.step, .permission)
        f.next(); f.next(); f.next(); f.next()
        XCTAssertEqual(f.step, .done)
        f.back(); XCTAssertEqual(f.step, .firstGesture)
        f.skip(); XCTAssertEqual(f.step, .done)
    }
}

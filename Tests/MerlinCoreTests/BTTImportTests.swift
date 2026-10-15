import XCTest
@testable import MerlinCore

final class BTTImportTests: XCTestCase {
    private func scan(_ json: String) throws -> BTTScan {
        try BTTImport.parse(Data(json.utf8))
    }

    func testTwoAndThreeFingerClickMapToMiddleClick() throws {
        let s = try scan("""
        [{"BTTTriggerClass":"BTTTriggerTypeMagicMouse","BTTTriggerType":20,
          "BTTTriggerTypeDescriptionReadOnly":"2 Finger Click","BTTPredefinedActionType":1,
          "BTTPredefinedActionName":"Middle Click (At Current Mouse Position)","BTTBelongsToApp":"Global"},
         {"BTTTriggerClass":"BTTTriggerTypeMagicMouse","BTTTriggerType":21,
          "BTTTriggerTypeDescriptionReadOnly":"3 Finger Click","BTTPredefinedActionType":1,
          "BTTPredefinedActionName":"Middle Click (At Current Mouse Position)"}]
        """)
        XCTAssertEqual(s.magicMouse.count, 2)
        XCTAssertEqual(s.magicMouse[0].trigger, Trigger(kind: .press, fingers: 2))
        XCTAssertEqual(s.magicMouse[1].trigger, Trigger(kind: .press, fingers: 3))
        XCTAssertEqual(s.magicMouse[0].action, .middleClick)
        XCTAssertNil(s.magicMouse[0].appName)
        XCTAssertTrue(s.magicMouse.allSatisfy(BTTImport.importable))
    }

    func testActionInsideActionsToExecute() throws {
        let s = try scan("""
        [{"BTTTriggerClass":"BTTTriggerTypeMagicMouse","BTTTriggerType":21,
          "BTTTriggerTypeDescriptionReadOnly":"3 Finger Click",
          "BTTActionsToExecute":[{"BTTPredefinedActionType":1,"BTTPredefinedActionName":"Middle Click"}]}]
        """)
        XCTAssertEqual(s.magicMouse.first?.action, .middleClick)
        XCTAssertTrue(BTTImport.importable(s.magicMouse[0]))
    }

    func testUnsupportedSwipeAction() throws {
        let s = try scan("""
        [{"BTTTriggerClass":"BTTTriggerTypeMagicMouse","BTTTriggerType":99,
          "BTTTriggerTypeDescriptionReadOnly":"4 Finger Swipe Down","BTTPredefinedActionType":5,
          "BTTPredefinedActionName":"Show Desktop"}]
        """)
        let item = try XCTUnwrap(s.magicMouse.first)
        XCTAssertEqual(item.trigger, Trigger(kind: .swipe, fingers: 4, direction: .down))
        XCTAssertNil(item.action)
        XCTAssertEqual(item.reason, "Bu eylem henüz devralınamıyor ('Show Desktop')")
        XCTAssertFalse(BTTImport.importable(item))
    }

    func testTriggerReasons() throws {
        let s = try scan("""
        [{"BTTTriggerClass":"BTTTriggerTypeMagicMouse","BTTTriggerType":1,"BTTTriggerTypeDescriptionReadOnly":"1 Finger Click","BTTPredefinedActionType":1},
         {"BTTTriggerClass":"BTTTriggerTypeMagicMouse","BTTTriggerType":2,"BTTTriggerTypeDescriptionReadOnly":"2 Finger Swipe Left","BTTPredefinedActionType":1},
         {"BTTTriggerClass":"BTTTriggerTypeMagicMouse","BTTTriggerType":3,"BTTTriggerTypeDescriptionReadOnly":"Shake","BTTPredefinedActionType":1},
         {"BTTTriggerClass":"BTTTriggerTypeMagicMouse","BTTTriggerType":4,"BTTTriggerTypeDescriptionReadOnly":"3 Finger Double-Tap","BTTPredefinedActionType":1},
         {"BTTTriggerClass":"BTTTriggerTypeMagicMouse","BTTTriggerType":5,"BTTTriggerTypeDescriptionReadOnly":"2 Finger Tap","BTTPredefinedActionType":1}]
        """)
        XCTAssertEqual(s.magicMouse[0].reason, "Tek parmakla tıklama normal sol tıklamadır")
        XCTAssertEqual(s.magicMouse[1].reason, "Bir ve iki parmakla kaydırma macOS kaydırmasıdır")
        XCTAssertEqual(s.magicMouse[2].reason, "Bu hareket henüz devralınamıyor")
        XCTAssertEqual(s.magicMouse[3].trigger, Trigger(kind: .doubleTap, fingers: 3))
        XCTAssertEqual(s.magicMouse[4].trigger, Trigger(kind: .tap, fingers: 2))
    }

    func testAppSpecificItemHasReason() throws {
        let s = try scan("""
        [{"BTTTriggerClass":"BTTTriggerTypeMagicMouse","BTTTriggerType":20,
          "BTTTriggerTypeDescriptionReadOnly":"2 Finger Click","BTTPredefinedActionType":1,
          "BTTBelongsToApp":"Finder"}]
        """)
        let item = s.magicMouse[0]
        XCTAssertEqual(item.appName, "Finder")
        XCTAssertEqual(item.reason, "Uygulamaya özel BTT atamaları elle eklenmeli (Finder)")
        XCTAssertFalse(BTTImport.importable(item))
    }

    func testFoldersAndEmptyItemsAreSkipped() throws {
        let s = try scan("""
        [{"BTTTriggerClass":"BTTTriggerTypeMagicMouse","BTTTriggerTypeDescriptionReadOnly":"Klasör"},
         {"BTTTriggerClass":"BTTTriggerTypeMagicMouse","BTTTriggerType":20,"BTTTriggerTypeDescriptionReadOnly":"2 Finger Click"},
         {}]
        """)
        XCTAssertTrue(s.magicMouse.isEmpty)
        XCTAssertTrue(s.otherCounts.isEmpty)
    }

    func testOtherCounts() throws {
        let s = try scan("""
        [{"BTTTriggerClass":"BTTTriggerTypeTouchpadAll","BTTTriggerType":1,"BTTPredefinedActionType":3},
         {"BTTTriggerClass":"BTTTriggerTypeTouchpadAll","BTTTriggerType":2,"BTTPredefinedActionType":3},
         {"BTTTriggerClass":"BTTTriggerTypeKeyboardShortcut","BTTTriggerType":0,"BTTPredefinedActionType":3},
         {"BTTTriggerClass":"BTTTriggerTypeTouchBar","BTTTriggerType":629,"BTTActionsToExecute":[{"a":1}]},
         {"BTTTriggerClass":"BTTTriggerTypeOtherTriggers","BTTTriggerType":5,"BTTPredefinedActionType":3},
         {"BTTTriggerType":7,"BTTPredefinedActionType":3},
         {"BTTTriggerClass":"BTTTriggerTypeTouchpadAll"}]
        """)
        XCTAssertEqual(s.otherCounts["BTTTriggerTypeTouchpadAll"], 2)
        XCTAssertEqual(s.otherCounts["BTTTriggerTypeKeyboardShortcut"], 1)
        XCTAssertEqual(s.otherCounts["BTTTriggerTypeTouchBar"], 1)
        XCTAssertEqual(s.otherCounts["BTTTriggerTypeOtherTriggers"], 2)
        XCTAssertEqual(BTTImport.className("BTTTriggerTypeTouchpadAll"), "Trackpad")
        XCTAssertEqual(BTTImport.className("BTTTriggerTypeKeyboardShortcut"), "Klavye kısayolu")
        XCTAssertEqual(BTTImport.className("BTTTriggerTypeTouchBar"), "Touch Bar")
        XCTAssertEqual(BTTImport.className("BTTTriggerTypeNormalMouse"), "Diğer tetikleyiciler")
    }

    func testInvalidJSONThrows() {
        XCTAssertThrowsError(try scan("bu json değil"))
        XCTAssertThrowsError(try scan("{\"a\":1}"))
    }

    func testDisabledItem() throws {
        let s = try scan("""
        [{"BTTTriggerClass":"BTTTriggerTypeMagicMouse","BTTTriggerType":20,
          "BTTTriggerTypeDescriptionReadOnly":"2 Finger Click","BTTPredefinedActionType":1,"BTTEnabled2":0},
         {"BTTTriggerClass":"BTTTriggerTypeMagicMouse","BTTTriggerType":21,
          "BTTTriggerTypeDescriptionReadOnly":"3 Finger Click","BTTPredefinedActionType":1,"BTTEnabled2":false}]
        """)
        XCTAssertFalse(s.magicMouse[0].enabled)
        XCTAssertFalse(s.magicMouse[1].enabled)
    }
}

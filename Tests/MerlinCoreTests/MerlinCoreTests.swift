import XCTest
@testable import MerlinCore

final class MerlinCoreTests: XCTestCase {
    private let env = ConflictEnvironment()

    private func b(_ t: Trigger, app: String? = nil, enabled: Bool = true,
                   action: GestureAction = .middleClick) -> GestureBinding {
        GestureBinding(trigger: t, action: action, enabled: enabled, appBundleID: app)
    }

    private func levels(_ binding: GestureBinding, among: [GestureBinding] = [],
                        env: ConflictEnvironment? = nil) -> [ConflictLevel] {
        ConflictChecker.check(binding, among: among, env: env ?? self.env).map(\.level)
    }

    func testNormalizedEquality() {
        let a = Trigger(kind: .press, fingers: 2, zone: .left, direction: .down, modifier: .none)
        let c = Trigger(kind: .press, fingers: 2, zone: .right, direction: .up, modifier: .none)
        XCTAssertEqual(a.normalized, c.normalized)
        let m1 = Trigger(kind: .press, fingers: 3, zone: .center, modifier: .fn)
        let m2 = Trigger(kind: .press, fingers: 0, zone: .any, modifier: .fn)
        XCTAssertEqual(m1.normalized, m2.normalized)
        let tap = Trigger(kind: .tap, fingers: 3, modifier: .shift)
        XCTAssertEqual(tap.normalized.modifier, .none)
        XCTAssertEqual(tap.normalized.fingers, 3)
        XCTAssertNotEqual(Trigger(kind: .swipe, fingers: 3, direction: .up).normalized,
                          Trigger(kind: .swipe, fingers: 3, direction: .down).normalized)
    }

    func testTitles() {
        XCTAssertEqual(Trigger(kind: .press, fingers: 1, zone: .center).title, "Orta bölgeye bas")
        XCTAssertEqual(Trigger(kind: .press, fingers: 2).title, "İki parmakla bas")
        XCTAssertEqual(Trigger(kind: .press, fingers: 0, modifier: .fn).title, "Fn + bas")
        XCTAssertEqual(Trigger(kind: .tap, fingers: 3).title, "Üç parmakla dokun")
        XCTAssertEqual(Trigger(kind: .swipe, fingers: 3, direction: .up).title, "Üç parmakla yukarı kaydır")
        XCTAssertEqual(Trigger(kind: .doubleTap, fingers: 1, zone: .right).title, "Sağ bölgeye çift dokun")
    }

    func testActionRoundTrip() throws {
        let actions: [GestureAction] = [
            .middleClick, .back, .forward,
            .shortcut(KeyCombo(keyCode: 8, modifiers: ["command"], display: "⌘C")),
            .system(.missionControl), .system(.spotlight),
            .openApp(path: "/Applications/Safari.app", name: "Safari"),
            .runShortcut(name: "Günaydın"),
        ]
        for a in actions {
            let data = try JSONEncoder().encode(a)
            XCTAssertEqual(try JSONDecoder().decode(GestureAction.self, from: data), a)
        }
        let json = String(data: try JSONEncoder().encode(GestureAction.runShortcut(name: "x")), encoding: .utf8)!
        XCTAssertTrue(json.contains("\"type\":\"runShortcut\""))
        XCTAssertFalse(json.contains("_0"))
        XCTAssertEqual(GestureAction.back.buttonNumber, 3)
        XCTAssertTrue(GestureAction.middleClick.isMouseButton)
        XCTAssertFalse(GestureAction.system(.lockScreen).isMouseButton)
        XCTAssertEqual(SystemAction.screenshot.keyCombo.keyCode, 23)
    }

    func testBindingSetRoundTripAndPreserved() throws {
        let good = b(Trigger(kind: .press, fingers: 2))
        let goodData = try JSONEncoder().encode(good)
        let goodStr = String(data: goodData, encoding: .utf8)!
        let unknown = """
        {"id":"\(UUID().uuidString)","enabled":true,"trigger":{"kind":"press","fingers":2,"zone":"any","direction":"up","modifier":"none"},"action":{"type":"teleport","x":1.5,"tags":["a",null,true]}}
        """
        let unknownTrigger = """
        {"foo":{"bar":[1,2,3]}}
        """
        let text = "{\"version\":1,\"bindings\":[\(goodStr),\(unknown),\(unknownTrigger)]}"
        let set = try JSONDecoder().decode(BindingSet.self, from: Data(text.utf8))
        XCTAssertEqual(set.bindings, [good])
        XCTAssertEqual(set.preserved.count, 2)

        let out = try JSONEncoder().encode(set)
        let again = try JSONDecoder().decode(BindingSet.self, from: out)
        XCTAssertEqual(again, set)
        let root = try JSONDecoder().decode([String: JSONValue].self, from: out)
        guard case .array(let arr)? = root["bindings"] else { return XCTFail("bindings dizi değil") }
        XCTAssertEqual(arr.count, 3)
        XCTAssertEqual(arr[1], try JSONDecoder().decode(JSONValue.self, from: Data(unknown.utf8)))
        XCTAssertEqual(arr[2], try JSONDecoder().decode(JSONValue.self, from: Data(unknownTrigger.utf8)))
        XCTAssertEqual(root["version"], .int(1))
    }

    func testDefaultBindingsFromLegacy() {
        let all = DefaultBindings.from(legacy: LegacyFlags(zoneClick: true, twoFingerClick: true,
                                                           threeFingerClick: true, threeFingerTap: true, fnDrag: true))
        XCTAssertEqual(all.count, 7)
        XCTAssertTrue(all.allSatisfy { $0.enabled && $0.action == .middleClick && $0.appBundleID == nil })
        let off = DefaultBindings.from(legacy: LegacyFlags(zoneClick: true, twoFingerClick: false,
                                                           threeFingerClick: false, threeFingerTap: true, fnDrag: false))
        func enabled(_ t: Trigger) -> Bool? { off.first { $0.trigger == t.normalized }?.enabled }
        XCTAssertEqual(enabled(Trigger(kind: .press, fingers: 1, zone: .center)), true)
        XCTAssertEqual(enabled(Trigger(kind: .press, fingers: 2)), false)
        XCTAssertEqual(enabled(Trigger(kind: .press, fingers: 3)), false)
        XCTAssertEqual(enabled(Trigger(kind: .press, fingers: 4)), false)
        XCTAssertEqual(enabled(Trigger(kind: .tap, fingers: 3)), true)
        XCTAssertEqual(enabled(Trigger(kind: .tap, fingers: 4)), true)
        XCTAssertEqual(enabled(Trigger(kind: .press, modifier: .fn)), false)
    }

    func testBindingIndex() {
        let t = Trigger(kind: .press, fingers: 2)
        let global = b(t, action: .back)
        let app = b(t, app: "com.test.app", action: .forward)
        let off = b(Trigger(kind: .tap, fingers: 3), enabled: false)
        let idx = BindingIndex(bindings: [global, app, off])
        XCTAssertEqual(idx.match(t, bundleID: "com.test.app")?.id, app.id)
        XCTAssertEqual(idx.match(t, bundleID: "com.other")?.id, global.id)
        XCTAssertEqual(idx.match(t, bundleID: nil)?.id, global.id)
        XCTAssertNil(idx.match(Trigger(kind: .tap, fingers: 3), bundleID: nil))
        XCTAssertFalse(idx.hasBinding(kind: .tap, fingers: 3))
        XCTAssertTrue(idx.hasBinding(kind: .press, fingers: 2))
        let dt = BindingIndex(bindings: [b(Trigger(kind: .doubleTap, fingers: 2), app: "a.b")])
        XCTAssertTrue(dt.hasDoubleTap(fingers: 2, zone: .any, bundleID: "a.b"))
        XCTAssertFalse(dt.hasDoubleTap(fingers: 2, zone: .any, bundleID: nil))
    }

    func testReserved() {
        XCTAssertTrue(levels(b(Trigger(kind: .press, fingers: 1, zone: .left))).contains(.reserved))
        XCTAssertTrue(levels(b(Trigger(kind: .press, fingers: 1, zone: .any))).contains(.reserved))
        XCTAssertTrue(levels(b(Trigger(kind: .swipe, fingers: 2, direction: .left))).contains(.reserved))
        XCTAssertTrue(levels(b(Trigger(kind: .tap, fingers: 1))).contains(.reserved))
        XCTAssertFalse(levels(b(Trigger(kind: .swipe, fingers: 3, direction: .left))).contains(.reserved))
    }

    func testUnsupportedAndDuplicate() {
        XCTAssertTrue(levels(b(Trigger(kind: .hold, fingers: 2))).contains(.unsupported))
        let a = b(Trigger(kind: .press, fingers: 3))
        let same = b(Trigger(kind: .press, fingers: 3, zone: .left))
        XCTAssertTrue(levels(a, among: [a, same]).contains(.duplicate))
        let otherScope = b(Trigger(kind: .press, fingers: 3), app: "com.x")
        XCTAssertFalse(levels(a, among: [a, otherScope]).contains(.duplicate))
        XCTAssertTrue(ConflictLevel.duplicate.blocksSave)
        XCTAssertFalse(ConflictLevel.btt.blocksSave)
    }

    func testEnvironmentConflicts() {
        let right = b(Trigger(kind: .press, fingers: 1, zone: .right))
        XCTAssertTrue(levels(right, env: ConflictEnvironment(mouseButtonMode: "TwoButton")).contains(.macOS))
        XCTAssertFalse(levels(right).contains(.macOS))
        let two = b(Trigger(kind: .press, fingers: 2))
        XCTAssertTrue(levels(two, env: ConflictEnvironment(bttRunning: true)).contains(.btt))
        XCTAssertFalse(levels(two).contains(.btt))
        let dt1 = b(Trigger(kind: .doubleTap, fingers: 1, zone: .center))
        XCTAssertTrue(levels(dt1, env: ConflictEnvironment(oneFingerDoubleTap: 1)).contains(.macOS))
        let opt = b(Trigger(kind: .press, modifier: .option))
        XCTAssertEqual(levels(opt), [.caution])
    }

    func testCenterSingleFingerClean() {
        XCTAssertTrue(levels(b(Trigger(kind: .press, fingers: 1, zone: .center)),
                             env: ConflictEnvironment(mouseButtonMode: "TwoButton", bttRunning: true)).isEmpty)
    }
}

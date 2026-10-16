import XCTest
@testable import MerlinCore

/// Çimdikleme tetiği, yakınlaştırma ve düzenleyicili orta tuş eylemleri.
final class PinchModelTests: XCTestCase {
    private let env = ConflictEnvironment(mouseButtonMode: "TwoButton", oneFingerDoubleTap: 1,
                                          twoFingerDoubleTap: 1, twoFingerHorizSwipe: 1, bttRunning: true)

    func testPinchNormalizedAndTitle() {
        let t = Trigger(kind: .pinch, fingers: 4, zone: .center, direction: .left, modifier: .shift).normalized
        XCTAssertEqual(t, Trigger(kind: .pinch, fingers: 2, zone: .any, direction: .up, modifier: .none))
        XCTAssertEqual(t.title, "İki parmakla çimdikle")
    }

    func testPinchTriggerCodableRoundTrip() throws {
        let t = Trigger(kind: .pinch, fingers: 2)
        let data = try JSONEncoder().encode(t)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"pinch\""))
        XCTAssertEqual(try JSONDecoder().decode(Trigger.self, from: data), t)
    }

    func testZoomCodableAndTitle() throws {
        let plain = GestureAction.zoom(style: .gesture, modifiers: [])
        let data = try JSONEncoder().encode(plain)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: String]
        XCTAssertEqual(obj, ["type": "zoom"])
        XCTAssertEqual(try JSONDecoder().decode(GestureAction.self, from: data), plain)
        XCTAssertEqual(plain.title, "Yakınlaştır / uzaklaştır")
        XCTAssertEqual(plain.zoomStyle, .gesture)
        XCTAssertNil(plain.buttonNumber)
        XCTAssertFalse(plain.isMouseButton)
        XCTAssertTrue(plain.isZoom)
        XCTAssertFalse(GestureAction.middleClick.isZoom)
        XCTAssertNil(GestureAction.middleClick.zoomStyle)
    }

    func testZoomModifiersCodableAndTitle() throws {
        let a = GestureAction.zoom(style: .wheel, modifiers: ["control"])
        let data = try JSONEncoder().encode(a)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(obj["type"] as? String, "zoom")
        XCTAssertEqual(obj["style"] as? String, "wheel")
        XCTAssertEqual(obj["modifiers"] as? [String], ["control"])
        XCTAssertEqual(try JSONDecoder().decode(GestureAction.self, from: data), a)
        XCTAssertEqual(a.title, "Yakınlaştır / uzaklaştır (⌃ + tekerlek)")
        XCTAssertEqual(a.normalizedModifiers, ["control"])
        XCTAssertNil(a.buttonNumber)
        // Sırasız, yinelenen ve bilinmeyen adlar çözerken düzelir.
        let raw = Data(#"{"type":"zoom","style":"wheel","modifiers":["command","fn","control","control"]}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(GestureAction.self, from: raw),
                       .zoom(style: .wheel, modifiers: ["control", "command"]))
    }

    func testZoomStylesRoundTripAndTitles() throws {
        let cases: [(GestureAction, [String: Any], String)] = [
            (.zoom(style: .gesture, modifiers: []), ["type": "zoom"], "Yakınlaştır / uzaklaştır"),
            (.zoom(style: .wheel, modifiers: []), ["type": "zoom", "style": "wheel"],
             "Yakınlaştır / uzaklaştır (tekerlek)"),
            (.zoom(style: .keys, modifiers: []), ["type": "zoom", "style": "keys"],
             "Yakınlaştır / uzaklaştır (⌘+ / ⌘−)"),
        ]
        for (action, expected, title) in cases {
            let data = try JSONEncoder().encode(action)
            let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(obj as NSDictionary, expected as NSDictionary)
            XCTAssertEqual(try JSONDecoder().decode(GestureAction.self, from: data), action)
            XCTAssertEqual(action.title, title)
        }
        XCTAssertEqual(ZoomStyle.allCases, [.gesture, .wheel, .keys])
    }

    func testZoomModifiersOnlyForWheel() throws {
        // Tekerlek dışındaki yöntemlerde düzenleyiciler anlamsız: normalleştirmede ve yazarken boşalır.
        let gesture = GestureAction.zoom(style: .gesture, modifiers: ["control"])
        XCTAssertEqual(gesture.normalizedModifiers, [])
        XCTAssertEqual(gesture.title, "Yakınlaştır / uzaklaştır")
        let keys = GestureAction.zoom(style: .keys, modifiers: ["shift"])
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(keys)) as? [String: Any])
        XCTAssertNil(obj["modifiers"])
        let raw = Data(#"{"type":"zoom","style":"keys","modifiers":["control"]}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(GestureAction.self, from: raw), .zoom(style: .keys, modifiers: []))
    }

    func testLegacyZoomResolvesStyle() throws {
        // Kart 26 öncesi: `style` yok. Düzenleyicisiz → trackpad hareketi, düzenleyicili → tekerlek.
        XCTAssertEqual(try JSONDecoder().decode(GestureAction.self, from: Data(#"{"type":"zoom"}"#.utf8)),
                       .zoom(style: .gesture, modifiers: []))
        XCTAssertEqual(try JSONDecoder().decode(GestureAction.self,
                                                from: Data(#"{"type":"zoom","modifiers":["control"]}"#.utf8)),
                       .zoom(style: .wheel, modifiers: ["control"]))
    }

    func testLegacyZoomFileDecodes() throws {
        // Kart 24'te kaydedilmiş dosya: düzenleyici alanı yok.
        let json = #"""
        {"version":1,"profiles":[],"bindings":[
          {"id":"7C9E6679-7425-40DE-944B-E07FC1F90AE7","trigger":{"kind":"pinch","fingers":2,"zone":"any","direction":"up","modifier":"none"},
           "action":{"type":"zoom"},"enabled":true,"builtInKey":"pinch"}
        ]}
        """#
        let set = try JSONDecoder().decode(BindingSet.self, from: Data(json.utf8))
        XCTAssertTrue(set.preserved.isEmpty)
        XCTAssertEqual(set.bindings.count, 1)
        XCTAssertEqual(set.bindings[0].action, .zoom(style: .gesture, modifiers: []))
        // Yeniden yazınca yine alansız biçim.
        let again = try JSONEncoder().encode(set.bindings[0].action)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: again) as? [String: String], ["type": "zoom"])
    }

    func testPinchAcceptsZoomWithModifiers() {
        let b = GestureBinding(trigger: Trigger(kind: .pinch, fingers: 2),
                               action: .zoom(style: .wheel, modifiers: ["control"]), appBundleID: "com.x")
        XCTAssertFalse(ConflictChecker.check(b, among: [b], env: env).contains { $0.level.blocksSave })
        for style in ZoomStyle.allCases {
            let s = GestureBinding(trigger: Trigger(kind: .pinch, fingers: 2), action: .zoom(style: style, modifiers: []))
            XCTAssertFalse(ConflictChecker.check(s, among: [s], env: env).contains { $0.level.blocksSave })
        }
        let wrong = GestureBinding(trigger: Trigger(kind: .press, fingers: 3),
                                   action: .zoom(style: .wheel, modifiers: ["control"]))
        XCTAssertTrue(ConflictChecker.check(wrong, among: [], env: env).contains { $0.level == .unsupported })
    }

    func testMiddleDragCodable() throws {
        let a = GestureAction.middleDrag(modifiers: ["control", "shift"])
        let data = try JSONEncoder().encode(a)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(obj["type"] as? String, "middleDrag")
        XCTAssertEqual(obj["modifiers"] as? [String], ["control", "shift"])
        XCTAssertEqual(try JSONDecoder().decode(GestureAction.self, from: data), a)
        // Sırasız, yinelenen ve bilinmeyen adlar çözerken düzelir.
        let raw = Data(#"{"type":"middleDrag","modifiers":["command","fn","shift","shift"]}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(GestureAction.self, from: raw),
                       .middleDrag(modifiers: ["shift", "command"]))
    }

    func testMiddleDragTitleOrderAndButton() {
        XCTAssertEqual(GestureAction.middleDrag(modifiers: ["shift"]).title, "Orta tuş + ⇧")
        XCTAssertEqual(GestureAction.middleDrag(modifiers: ["command", "shift", "option", "control"]).title,
                       "Orta tuş + ⌃⌥⇧⌘")
        XCTAssertEqual(GestureAction.middleDrag(modifiers: ["shift"]).buttonNumber, 2)
        XCTAssertTrue(GestureAction.middleDrag(modifiers: ["shift"]).isMouseButton)
        XCTAssertEqual(GestureAction.normalizedModifiers(["shift", "control", "shift", "x"]), ["control", "shift"])
        XCTAssertEqual(GestureAction.middleDrag(modifiers: ["option", "control"]).normalizedModifiers,
                       ["control", "option"])
    }

    func testMiddleDragOpensMiddleDragSession() {
        var m = PressStateMachine()
        let b = GestureBinding(trigger: Trigger(kind: .press, fingers: 2), action: .middleDrag(modifiers: ["shift"]))
        XCTAssertEqual(m.mouseDown(.left, binding: b).0, .convert(buttonNumber: 2))
        XCTAssertTrue(m.isMiddleDragActive)
        _ = m.mouseUp(.left)
        XCTAssertFalse(m.isMiddleDragActive)
    }

    func testMiddleDragValidation() {
        let empty = GestureBinding(trigger: Trigger(kind: .press, fingers: 3), action: .middleDrag(modifiers: []))
        let r = BindingValidation.evaluate(empty, among: [], env: ConflictEnvironment())
        XCTAssertEqual(r.missing, "Düzenleyici tuş seçilmedi")
        XCTAssertFalse(r.canSave)
        let ok = GestureBinding(trigger: Trigger(kind: .press, fingers: 3), action: .middleDrag(modifiers: ["shift"]))
        XCTAssertNil(BindingValidation.evaluate(ok, among: [], env: ConflictEnvironment()).missing)
    }

    func testPinchConflicts() {
        let pinch = Trigger(kind: .pinch, fingers: 2)
        let good = GestureBinding(trigger: pinch, action: .zoom(style: .gesture, modifiers: []))
        let goodConflicts = ConflictChecker.check(good, among: [good], env: env)
        XCTAssertTrue(goodConflicts.isEmpty, "\(goodConflicts)")

        let wrong = GestureBinding(trigger: pinch, action: .middleClick)
        let c1 = ConflictChecker.check(wrong, among: [], env: env).filter { $0.level == .unsupported }
        XCTAssertEqual(c1.map(\.detail), ["Çimdikleme yalnız yakınlaştırma eylemine atanabilir."])

        let zoomElsewhere = GestureBinding(trigger: Trigger(kind: .press, fingers: 3),
                                           action: .zoom(style: .keys, modifiers: []))
        let c2 = ConflictChecker.check(zoomElsewhere, among: [], env: ConflictEnvironment())
            .filter { $0.level == .unsupported }
        XCTAssertEqual(c2.map(\.detail), ["Yakınlaştırma eylemi yalnız çimdikleme ya da kenar kaydırmayla kullanılır."])

        // Aynı kapsamda ikinci pinch: yinelenen.
        let other = GestureBinding(trigger: pinch, action: .zoom(style: .wheel, modifiers: []))
        XCTAssertTrue(ConflictChecker.check(other, among: [good, other], env: env).contains { $0.level == .duplicate })
        let app = GestureBinding(trigger: pinch, action: .zoom(style: .gesture, modifiers: []), appBundleID: "com.x")
        XCTAssertFalse(ConflictChecker.check(app, among: [good, app], env: env).contains { $0.level == .duplicate })
    }

    func testPinchIndexMatch() {
        let b = GestureBinding(trigger: Trigger(kind: .pinch, fingers: 2), action: .zoom(style: .gesture, modifiers: []))
        let idx = BindingIndex(bindings: [b])
        XCTAssertEqual(idx.match(Trigger(kind: .pinch, fingers: 2), bundleID: nil)?.id, b.id)
        XCTAssertNil(idx.match(Trigger(kind: .press, fingers: 2), bundleID: nil))
    }
}

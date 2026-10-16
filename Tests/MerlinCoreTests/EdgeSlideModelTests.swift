import XCTest
@testable import MerlinCore

/// Kenar kaydırma tetiği, adım eylemleri, çakışma ve doğrulama kuralları.
final class EdgeSlideModelTests: XCTestCase {
    private let env = ConflictEnvironment()
    private let up = KeyCombo(keyCode: 126, modifiers: ["command"], display: "⌘↑")
    private let down = KeyCombo(keyCode: 125, modifiers: ["command"], display: "⌘↓")

    private func unsupported(_ t: Trigger, _ a: GestureAction) -> [String] {
        ConflictChecker.check(GestureBinding(trigger: t, action: a), among: [], env: env)
            .filter { $0.level == .unsupported }.map(\.detail)
    }

    // MARK: Tetik

    func testNormalized() {
        let messy = Trigger(kind: .edgeSlide, fingers: 3, zone: .center, direction: .left, modifier: .shift).normalized
        XCTAssertEqual(messy, Trigger(kind: .edgeSlide, fingers: 1, zone: .leftEdge, direction: .up, modifier: .none))
        XCTAssertEqual(Trigger(kind: .edgeSlide, zone: .rightEdge, direction: .down).normalized.zone, .rightEdge)
        // Başka türlerde kenar bölgesi "her yer" olur; diğer normalleştirme değişmez.
        XCTAssertEqual(Trigger(kind: .doubleTap, fingers: 1, zone: .rightEdge).normalized,
                       Trigger(kind: .doubleTap, fingers: 1, zone: .any))
        XCTAssertEqual(Trigger(kind: .press, fingers: 1, zone: .leftEdge).normalized.zone, .any)
        XCTAssertEqual(Trigger(kind: .press, fingers: 1, zone: .center).normalized.zone, .center)
    }

    func testTitlesAndZoneNames() {
        XCTAssertEqual(Trigger(kind: .edgeSlide, zone: .leftEdge).title, "Sol kenarda kaydır")
        XCTAssertEqual(Trigger(kind: .edgeSlide, zone: .rightEdge).title, "Sağ kenarda kaydır")
        XCTAssertEqual(Zone.leftEdge.displayName, "Sol kenar")
        XCTAssertEqual(Zone.rightEdge.displayName, "Sağ kenar")
        XCTAssertEqual(Zone.leftEdge.rawValue, "leftEdge")
        XCTAssertEqual(Zone.rightEdge.rawValue, "rightEdge")
        XCTAssertEqual(GestureKind.edgeSlide.rawValue, "edgeSlide")
    }

    func testClassifyNeverReturnsEdges() {
        let layout = ZoneLayout.standard
        for x in stride(from: Float(0), through: 1, by: 0.05) {
            for y in stride(from: Float(0), through: 1, by: 0.05) {
                XCTAssertFalse(Zone.classify(x: x, y: y, layout: layout).isEdge)
            }
        }
    }

    func testTriggerCodableRoundTrip() throws {
        let t = Trigger(kind: .edgeSlide, zone: .rightEdge).normalized
        let data = try JSONEncoder().encode(t)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(obj["kind"] as? String, "edgeSlide")
        XCTAssertEqual(obj["zone"] as? String, "rightEdge")
        XCTAssertEqual(try JSONDecoder().decode(Trigger.self, from: data), t)
    }

    func testIndexMatchesEdge() {
        let b = GestureBinding(trigger: Trigger(kind: .edgeSlide, zone: .leftEdge), action: .volume)
        let idx = BindingIndex(bindings: [b])
        XCTAssertEqual(idx.match(Trigger(kind: .edgeSlide, zone: .leftEdge), bundleID: nil)?.id, b.id)
        XCTAssertNil(idx.match(Trigger(kind: .edgeSlide, zone: .rightEdge), bundleID: nil))
    }

    // MARK: Eylemler

    func testActionCodable() throws {
        func json(_ a: GestureAction) throws -> [String: Any] {
            try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(a)) as? [String: Any])
        }
        XCTAssertEqual(try json(.volume) as? [String: String], ["type": "volume"])
        XCTAssertEqual(try json(.brightness) as? [String: String], ["type": "brightness"])
        let pair = GestureAction.stepShortcut(up: up, down: down)
        let obj = try json(pair)
        XCTAssertEqual(obj["type"] as? String, "stepShortcut")
        let u = try XCTUnwrap(obj["up"] as? [String: Any])
        XCTAssertEqual(u["keyCode"] as? Int, 126)
        XCTAssertEqual(u["modifiers"] as? [String], ["command"])
        XCTAssertEqual(u["display"] as? String, "⌘↑")
        XCTAssertNotNil(obj["down"] as? [String: Any])
        for a in [GestureAction.volume, .brightness, pair] {
            XCTAssertEqual(try JSONDecoder().decode(GestureAction.self, from: JSONEncoder().encode(a)), a)
        }
    }

    func testTitlesAndFlags() {
        XCTAssertEqual(GestureAction.volume.title, "Ses")
        XCTAssertEqual(GestureAction.brightness.title, "Parlaklık")
        XCTAssertEqual(GestureAction.stepShortcut(up: up, down: down).title, "Kısayol çifti: ⌘↑ / ⌘↓")
        for a in [GestureAction.volume, .brightness, .stepShortcut(up: up, down: down)] {
            XCTAssertNil(a.buttonNumber)
            XCTAssertTrue(a.isStepAction)
            XCTAssertTrue(a.isEdgeOnly)
        }
        XCTAssertTrue(GestureAction.zoom(style: .gesture, modifiers: []).isStepAction)
        XCTAssertFalse(GestureAction.zoom(style: .gesture, modifiers: []).isEdgeOnly)
        XCTAssertFalse(GestureAction.middleClick.isStepAction)
        XCTAssertFalse(GestureAction.shortcut(up).isStepAction)
    }

    func testOldVersionPreservesUnknownEdgeBinding() throws {
        // Bu sürümün tanımadığı bir tür (ileride eklenecek) korunur; tanıdığı kenar ataması çözülür.
        let json = #"""
        {"version":1,"bindings":[
          {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","trigger":{"kind":"edgeSlide","fingers":1,"zone":"leftEdge","direction":"up","modifier":"none"},"action":{"type":"volume"},"enabled":false,"builtInKey":"edge-left"},
          {"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF","trigger":{"kind":"edgeSlide","fingers":1,"zone":"rightEdge","direction":"up","modifier":"none"},"action":{"type":"rocket"},"enabled":true}
        ]}
        """#
        let set = try JSONDecoder().decode(BindingSet.self, from: Data(json.utf8))
        XCTAssertEqual(set.bindings.count, 1)
        XCTAssertEqual(set.bindings[0].action, .volume)
        XCTAssertFalse(set.bindings[0].enabled)
        XCTAssertEqual(set.preserved.count, 1)
    }

    // MARK: Çakışma

    func testEdgeAcceptsOnlyStepActions() {
        let left = Trigger(kind: .edgeSlide, zone: .leftEdge)
        for a in [GestureAction.volume, .brightness, .zoom(style: .gesture, modifiers: []),
                  .zoom(style: .wheel, modifiers: ["control"]), .stepShortcut(up: up, down: down)] {
            XCTAssertTrue(unsupported(left, a).isEmpty, "\(a)")
            let b = GestureBinding(trigger: left, action: a)
            XCTAssertTrue(ConflictChecker.check(b, among: [b], env: env).isEmpty, "\(a)")
        }
        for a in [GestureAction.middleClick, .back, .shortcut(up), .middleDrag(modifiers: ["shift"])] {
            XCTAssertEqual(unsupported(left, a),
                           ["Kenar kaydırma yalnız ses, parlaklık, yakınlaştırma ya da kısayol çifti ile kullanılır."])
        }
    }

    func testEdgeOnlyActionsElsewhere() {
        for t in [Trigger(kind: .press, fingers: 3), Trigger(kind: .tap, fingers: 3),
                  Trigger(kind: .swipe, fingers: 3, direction: .up)] {
            for a in [GestureAction.volume, .brightness, .stepShortcut(up: up, down: down)] {
                XCTAssertEqual(unsupported(t, a), ["Bu eylem yalnız kenar kaydırmayla kullanılır."], "\(t) \(a)")
            }
        }
        // Çimdikleme yine yalnız yakınlaştırma.
        let pinch = Trigger(kind: .pinch, fingers: 2)
        XCTAssertTrue(unsupported(pinch, .volume).contains("Çimdikleme yalnız yakınlaştırma eylemine atanabilir."))
        XCTAssertTrue(unsupported(pinch, .zoom(style: .gesture, modifiers: [])).isEmpty)
        // Yakınlaştırma başka tetikte desteklenmez.
        XCTAssertEqual(unsupported(Trigger(kind: .press, fingers: 2), .zoom(style: .keys, modifiers: [])),
                       ["Yakınlaştırma eylemi yalnız çimdikleme ya da kenar kaydırmayla kullanılır."])
    }

    func testEdgeDuplicateAndScopes() {
        let left = Trigger(kind: .edgeSlide, zone: .leftEdge)
        let a = GestureBinding(trigger: left, action: .volume)
        let b = GestureBinding(trigger: left, action: .brightness)
        XCTAssertTrue(ConflictChecker.check(b, among: [a, b], env: env).contains { $0.level == .duplicate })
        let right = GestureBinding(trigger: Trigger(kind: .edgeSlide, zone: .rightEdge), action: .brightness)
        XCTAssertFalse(ConflictChecker.check(right, among: [a, right], env: env).contains { $0.level == .duplicate })
    }

    // MARK: Doğrulama

    func testStepShortcutValidation() {
        let empty = KeyCombo(keyCode: 0, modifiers: [], display: "")
        let left = Trigger(kind: .edgeSlide, zone: .leftEdge)
        for pair in [GestureAction.stepShortcut(up: empty, down: down), .stepShortcut(up: up, down: empty),
                     .stepShortcut(up: empty, down: empty)] {
            let r = BindingValidation.evaluate(GestureBinding(trigger: left, action: pair), among: [], env: env)
            XCTAssertEqual(r.missing, "Kısayol çifti eksik")
            XCTAssertFalse(r.canSave)
        }
        let ok = BindingValidation.evaluate(GestureBinding(trigger: left, action: .stepShortcut(up: up, down: down)),
                                            among: [], env: env)
        XCTAssertNil(ok.missing)
        XCTAssertTrue(ok.canSave)
        XCTAssertTrue(BindingValidation.evaluate(GestureBinding(trigger: left, action: .volume), among: [], env: env).canSave)
    }
}

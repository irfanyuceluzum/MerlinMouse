import XCTest
@testable import MerlinCore

/// Hazır uygulama profilleri (Blender, Bambu Studio, CHITUBOX).
final class AppPresetsTests: XCTestCase {
    private let env = ConflictEnvironment()

    private var globalDefaults: [GestureBinding] {
        DefaultBindings.definitions.map {
            GestureBinding(trigger: $0.trigger, action: $0.action, enabled: true, builtInKey: $0.key, device: $0.device)
        }
    }

    private func preset(_ id: String) throws -> AppPreset {
        try XCTUnwrap(AppPresets.preset(id: id))
    }

    func testAllThreePresetsExist() throws {
        XCTAssertEqual(AppPresets.all.map(\.id), ["blender", "bambu-studio", "chitubox"])
        let blender = try preset("blender")
        XCTAssertEqual(blender.bundleIDs, ["org.blenderfoundation.blender"])
        XCTAssertEqual(blender.bindings, [
            PresetBinding(trigger: Trigger(kind: .press, fingers: 2), action: .middleDrag(modifiers: ["shift"])),
            PresetBinding(trigger: Trigger(kind: .press, fingers: 3), action: .middleDrag(modifiers: ["control"])),
            PresetBinding(trigger: Trigger(kind: .tap, fingers: 1, zone: .rear), action: .middleDrag(modifiers: ["option"])),
        ])
        let bambu = try preset("bambu-studio")
        XCTAssertEqual(bambu.bundleIDs, ["com.bambulab.bambu-studio"])
        XCTAssertEqual(bambu.bindings.map(\.action),
                       [.middleClick, .middleClick, .zoom(style: .wheel, modifiers: [])])
        XCTAssertTrue(bambu.notes.contains("Çimdikleme bu profilde fare tekerleği gönderir."))
        let chitubox = try preset("chitubox")
        XCTAssertTrue(chitubox.bundleIDs.isEmpty)
        XCTAssertEqual(chitubox.bindings, [
            PresetBinding(trigger: Trigger(kind: .pinch, fingers: 2), action: .zoom(style: .wheel, modifiers: ["control"])),
        ])
        for p in AppPresets.all {
            XCTAssertFalse(p.notes.isEmpty, p.id)
            XCTAssertFalse(p.sources.isEmpty, p.id)
            XCTAssertTrue(p.sources.allSatisfy { URL(string: $0)?.scheme == "https" }, p.id)
            XCTAssertEqual(p.nameMatch, p.nameMatch.lowercased(), p.id)
        }
    }

    func testPresetBindingsHaveNoBlockingConflicts() {
        for p in AppPresets.all {
            for (amongDefaults, base) in [(false, [GestureBinding]()), (true, globalDefaults)] {
                let applied = AppPresets.apply(p, bundleID: "com.example.app", appName: "Örnek", to: BindingSet(bindings: base))
                for b in applied.set.bindings where b.appBundleID != nil {
                    let blocking = ConflictChecker.check(b, among: applied.set.bindings, env: env).filter { $0.level.blocksSave }
                    XCTAssertTrue(blocking.isEmpty, "\(p.id) \(b.trigger.title) defaults=\(amongDefaults): \(blocking)")
                    XCTAssertTrue(BindingValidation.evaluate(b, among: applied.set.bindings, env: env).canSave,
                                  "\(p.id) \(b.trigger.title)")
                }
            }
        }
    }

    func testApplyAddsProfileAndScopedBindings() throws {
        let p = try preset("blender")
        let base = BindingSet(bindings: globalDefaults, preserved: [.string("eski")],
                              profiles: [ProfileApp(bundleID: "com.other", name: "Diğer")])
        let r = AppPresets.apply(p, bundleID: "org.blenderfoundation.blender", appName: "Blender", to: base)
        XCTAssertEqual(r.added, 3)
        XCTAssertEqual(r.skipped, 0)
        XCTAssertEqual(r.set.profiles, [ProfileApp(bundleID: "com.other", name: "Diğer"),
                                        ProfileApp(bundleID: "org.blenderfoundation.blender", name: "Blender")])
        XCTAssertEqual(r.set.preserved, base.preserved)
        // Genel atamalar aynen kalır.
        XCTAssertEqual(Array(r.set.bindings.prefix(base.bindings.count)), base.bindings)
        let added = r.set.bindings.filter { $0.appBundleID == "org.blenderfoundation.blender" }
        XCTAssertEqual(added.count, 3)
        for b in added {
            XCTAssertEqual(b.appName, "Blender")
            XCTAssertTrue(b.enabled)
            XCTAssertNil(b.builtInKey)
        }
        XCTAssertEqual(added.map(\.trigger), p.bindings.map(\.trigger))
        XCTAssertEqual(added.map(\.action), p.bindings.map(\.action))
    }

    func testSecondApplyAddsNothing() throws {
        let p = try preset("bambu-studio")
        let once = AppPresets.apply(p, bundleID: "com.bambulab.bambu-studio", appName: "Bambu Studio",
                                    to: BindingSet(bindings: globalDefaults))
        XCTAssertEqual(once.added, 3)
        let twice = AppPresets.apply(p, bundleID: "com.bambulab.bambu-studio", appName: "Bambu Studio", to: once.set)
        XCTAssertEqual(twice.added, 0)
        XCTAssertEqual(twice.skipped, 3)
        XCTAssertEqual(twice.set, once.set)
        XCTAssertEqual(twice.set.profiles.count, 1)
    }

    func testExistingScopedBindingIsKeptAndSkipped() throws {
        let p = try preset("blender")
        let id = "org.blenderfoundation.blender"
        // Kullanıcının kendi (kapalı) iki parmak ataması ve açık arka dokunma ataması.
        let mine = GestureBinding(trigger: Trigger(kind: .press, fingers: 2), action: .back, enabled: false,
                                  appBundleID: id, appName: "Blender")
        let rear = GestureBinding(trigger: Trigger(kind: .tap, fingers: 1, zone: .rear), action: .forward,
                                  appBundleID: id, appName: "Blender")
        let other = GestureBinding(trigger: Trigger(kind: .press, fingers: 3), action: .back,
                                   appBundleID: "com.other", appName: "Diğer")
        let base = BindingSet(bindings: globalDefaults + [mine, rear, other],
                              profiles: [ProfileApp(bundleID: id, name: "Blender 4")])
        let r = AppPresets.apply(p, bundleID: id, appName: "Blender", to: base)
        XCTAssertEqual(r.added, 1)
        XCTAssertEqual(r.skipped, 2)
        // Mevcut atamalar değişmeden, aynı sırada kalır; profil yinelenmez ve adı değişmez.
        XCTAssertEqual(Array(r.set.bindings.prefix(base.bindings.count)), base.bindings)
        XCTAssertEqual(r.set.profiles, base.profiles)
        let added = try XCTUnwrap(r.set.bindings.last)
        XCTAssertEqual(added.trigger, Trigger(kind: .press, fingers: 3).normalized)
        XCTAssertEqual(added.action, .middleDrag(modifiers: ["control"]))
        XCTAssertEqual(added.appBundleID, id)
    }

    func testMatches() throws {
        let blender = try preset("blender")
        XCTAssertTrue(AppPresets.matches(blender, bundleID: "org.blenderfoundation.blender", name: "X"))
        XCTAssertTrue(AppPresets.matches(blender, bundleID: "com.example", name: "Blender 4.5"))
        XCTAssertFalse(AppPresets.matches(blender, bundleID: "com.apple.Notes", name: "Notlar"))
        let bambu = try preset("bambu-studio")
        XCTAssertTrue(AppPresets.matches(bambu, bundleID: "com.bambulab.bambu-studio", name: nil))
        XCTAssertTrue(AppPresets.matches(bambu, bundleID: nil, name: "BambuStudio"))
        let chitubox = try preset("chitubox")
        XCTAssertTrue(AppPresets.matches(chitubox, bundleID: "com.cbd-3d.CHITUBOX_Basic", name: "Other"))
        XCTAssertTrue(AppPresets.matches(chitubox, bundleID: "com.x", name: "CHITUBOX Basic"))
        XCTAssertFalse(AppPresets.matches(chitubox, bundleID: nil, name: nil))
    }
}

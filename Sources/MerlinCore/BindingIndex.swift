import Foundation

/// Tanıyıcının sıcak yolu için O(1) sözlük eşleştirme. Her aygıtın atamaları ayrı tutulur.
public struct BindingIndex {
    private struct Tables {
        var global: [Trigger: GestureBinding] = [:]
        var perApp: [String: [Trigger: GestureBinding]] = [:]
        // Yön ve düzenleyiciden bağımsız "böyle bir şekil var mı" kümeleri.
        var globalShapes: Set<Trigger> = []
        var appShapes: [String: Set<Trigger>] = [:]
    }

    private var tables: [InputDeviceKind: Tables] = [:]

    /// Yalnız `enabled` atamalar indekslenir; aynı aygıtta aynı tetikte ilk atama kazanır.
    public init(bindings: [GestureBinding]) {
        for b in bindings where b.enabled {
            let t = b.trigger.normalized
            let shape = Trigger(kind: t.kind, fingers: t.fingers, zone: t.zone)
            var tb = tables[b.device] ?? Tables()
            if let app = b.appBundleID {
                if tb.perApp[app, default: [:]][t] == nil { tb.perApp[app, default: [:]][t] = b }
                if t.modifier == .none { tb.appShapes[app, default: []].insert(shape) }
            } else {
                if tb.global[t] == nil { tb.global[t] = b }
                if t.modifier == .none { tb.globalShapes.insert(shape) }
            }
            tables[b.device] = tb
        }
    }

    /// Önce uygulamaya özel, sonra genel; yalnız verilen aygıtın atamaları.
    /// Eşleşme yoksa geri düşer: tek parmak tap/doubleTap bölgesi → "Her yer";
    /// 4 parmak → 3 parmak ("3+ parmak" atamaları).
    public func match(_ trigger: Trigger, bundleID: String?,
                      device: InputDeviceKind = .magicMouse) -> GestureBinding? {
        guard let tb = tables[device] else { return nil }
        let t = trigger.normalized
        if let b = Self.lookup(tb, t, bundleID: bundleID) { return b }
        if t.fingers == 1, t.zone != .any, t.zone != .rear, t.kind == .tap || t.kind == .doubleTap {
            var any = t
            any.zone = .any
            if let b = Self.lookup(tb, any, bundleID: bundleID) { return b }
        }
        if t.fingers == 4, t.kind != .hold {
            var three = t
            three.fingers = 3
            if let b = Self.lookup(tb, three.normalized, bundleID: bundleID) { return b }
        }
        return nil
    }

    private static func lookup(_ tb: Tables, _ t: Trigger, bundleID: String?) -> GestureBinding? {
        if let id = bundleID, let b = tb.perApp[id]?[t] { return b }
        return tb.global[t]
    }

    /// Verilen aygıtta, tür/parmak/bölgede (düzenleyicisiz) herhangi bir atama var mı.
    public func hasBinding(kind: GestureKind, fingers: Int, zone: Zone = .any,
                           bundleID: String? = nil, device: InputDeviceKind = .magicMouse) -> Bool {
        guard let tb = tables[device] else { return false }
        let shape = Trigger(kind: kind, fingers: fingers, zone: zone).normalized
        let s = Trigger(kind: shape.kind, fingers: shape.fingers, zone: shape.zone)
        if let id = bundleID, tb.appShapes[id]?.contains(s) == true { return true }
        return tb.globalShapes.contains(s)
    }

    /// Öndeki uygulama için bu aygıtta eşleşebilecek (açık) bir atama var mı: genel ya da o uygulamaya özel.
    public func hasBindings(device: InputDeviceKind, bundleID: String?) -> Bool {
        guard let tb = tables[device] else { return false }
        if !tb.global.isEmpty { return true }
        if let id = bundleID, let app = tb.perApp[id], !app.isEmpty { return true }
        return false
    }

    /// Bu aygıtta herhangi bir kapsamda açık atama var mı.
    public func hasAnyBinding(device: InputDeviceKind) -> Bool {
        guard let tb = tables[device] else { return false }
        return !tb.global.isEmpty || tb.perApp.values.contains { !$0.isEmpty }
    }

    public func hasDoubleTap(fingers: Int, zone: Zone = .any, bundleID: String? = nil,
                             device: InputDeviceKind = .magicMouse) -> Bool {
        if hasBinding(kind: .doubleTap, fingers: fingers, zone: zone, bundleID: bundleID, device: device) { return true }
        if fingers == 1, zone != .any, zone != .rear {
            return hasBinding(kind: .doubleTap, fingers: 1, zone: .any, bundleID: bundleID, device: device)
        }
        return false
    }
}

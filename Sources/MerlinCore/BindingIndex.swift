import Foundation

/// Tanıyıcının sıcak yolu için O(1) sözlük eşleştirme.
public struct BindingIndex {
    private var global: [Trigger: GestureBinding] = [:]
    private var perApp: [String: [Trigger: GestureBinding]] = [:]
    // Yön ve düzenleyiciden bağımsız "böyle bir şekil var mı" kümeleri.
    private var globalShapes: Set<Trigger> = []
    private var appShapes: [String: Set<Trigger>] = [:]

    /// Yalnız `enabled` atamalar indekslenir; aynı tetikte ilk atama kazanır.
    public init(bindings: [GestureBinding]) {
        for b in bindings where b.enabled {
            let t = b.trigger.normalized
            let shape = Trigger(kind: t.kind, fingers: t.fingers, zone: t.zone)
            if let app = b.appBundleID {
                if perApp[app, default: [:]][t] == nil { perApp[app, default: [:]][t] = b }
                if t.modifier == .none { appShapes[app, default: []].insert(shape) }
            } else {
                if global[t] == nil { global[t] = b }
                if t.modifier == .none { globalShapes.insert(shape) }
            }
        }
    }

    /// Önce uygulamaya özel, sonra genel.
    /// Eşleşme yoksa geri düşer: tek parmak tap/doubleTap bölgesi → "Her yer";
    /// 4 parmak → 3 parmak ("3+ parmak" atamaları).
    public func match(_ trigger: Trigger, bundleID: String?) -> GestureBinding? {
        let t = trigger.normalized
        if let b = lookup(t, bundleID: bundleID) { return b }
        if t.fingers == 1, t.zone != .any, t.zone != .rear, t.kind == .tap || t.kind == .doubleTap {
            var any = t
            any.zone = .any
            if let b = lookup(any, bundleID: bundleID) { return b }
        }
        if t.fingers == 4, t.kind != .hold {
            var three = t
            three.fingers = 3
            if let b = lookup(three.normalized, bundleID: bundleID) { return b }
        }
        return nil
    }

    private func lookup(_ t: Trigger, bundleID: String?) -> GestureBinding? {
        if let id = bundleID, let b = perApp[id]?[t] { return b }
        return global[t]
    }

    /// Verilen tür/parmak/bölgede (düzenleyicisiz) herhangi bir atama var mı.
    public func hasBinding(kind: GestureKind, fingers: Int, zone: Zone = .any,
                           bundleID: String? = nil) -> Bool {
        let shape = Trigger(kind: kind, fingers: fingers, zone: zone).normalized
        let s = Trigger(kind: shape.kind, fingers: shape.fingers, zone: shape.zone)
        if let id = bundleID, appShapes[id]?.contains(s) == true { return true }
        return globalShapes.contains(s)
    }

    public func hasDoubleTap(fingers: Int, zone: Zone = .any, bundleID: String? = nil) -> Bool {
        if hasBinding(kind: .doubleTap, fingers: fingers, zone: zone, bundleID: bundleID) { return true }
        if fingers == 1, zone != .any, zone != .rear {
            return hasBinding(kind: .doubleTap, fingers: 1, zone: .any, bundleID: bundleID)
        }
        return false
    }
}

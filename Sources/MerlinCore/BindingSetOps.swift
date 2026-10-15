import Foundation

/// Atama listesi üzerinde kural uygulayan saf işlemler: bir hareket için
/// kapsam başına tek etkin atama bulunur.
public enum BindingSetOps {
    public static func setEnabled(_ id: UUID, _ enabled: Bool, in bindings: [GestureBinding]) -> [GestureBinding] {
        guard let i = bindings.firstIndex(where: { $0.id == id }) else { return bindings }
        var out = bindings
        out[i].enabled = enabled
        if enabled { disableRivals(of: out[i], in: &out) }
        return out
    }

    public static func upsert(_ binding: GestureBinding, in bindings: [GestureBinding]) -> [GestureBinding] {
        var out = bindings
        if let i = out.firstIndex(where: { $0.id == binding.id }) {
            out[i] = binding
        } else {
            out.append(binding)
        }
        if binding.enabled {
            removeDisabledRivals(of: binding, in: &out)
            disableRivals(of: binding, in: &out)
        }
        return out
    }

    /// Aynı tetik + kapsamdaki kapalı diğer atamalar yeni etkin atamanın yerine geçer.
    private static func removeDisabledRivals(of b: GestureBinding, in list: inout [GestureBinding]) {
        let t = b.trigger.normalized
        list.removeAll { $0.id != b.id && !$0.enabled && $0.appBundleID == b.appBundleID && $0.trigger.normalized == t }
    }

    private static func disableRivals(of b: GestureBinding, in list: inout [GestureBinding]) {
        let t = b.trigger.normalized
        for j in list.indices where list[j].id != b.id && list[j].enabled
            && list[j].appBundleID == b.appBundleID && list[j].trigger.normalized == t {
            list[j].enabled = false
        }
    }
}

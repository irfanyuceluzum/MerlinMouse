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

    public static func upsert(_ input: GestureBinding, in bindings: [GestureBinding]) -> [GestureBinding] {
        var binding = input
        // Temel hareketler her zaman genel kapsamdadır.
        if binding.isBuiltIn { binding.appBundleID = nil; binding.appName = nil }
        var out = bindings
        if let i = out.firstIndex(where: { $0.id == binding.id }) {
            out[i] = binding
        } else {
            out.append(binding)
        }
        if binding.enabled {
            removeDisabledRivals(of: binding, in: &out)
            removeOpenRivals(of: binding, in: &out)
            disableRivals(of: binding, in: &out)
        }
        return out
    }

    /// Temel atama silinemez; eklenen atama kaldırılır.
    public static func remove(_ id: UUID, in bindings: [GestureBinding]) -> [GestureBinding] {
        guard let b = bindings.first(where: { $0.id == id }), !b.isBuiltIn else { return bindings }
        return bindings.filter { $0.id != id }
    }

    /// Aynı tetik + kapsamdaki kapalı diğer atamalar yeni etkin atamanın yerine geçer (temel olanlar kalır).
    private static func removeDisabledRivals(of b: GestureBinding, in list: inout [GestureBinding]) {
        let t = b.trigger.normalized
        list.removeAll { $0.id != b.id && !$0.enabled && !$0.isBuiltIn && $0.appBundleID == b.appBundleID && $0.trigger.normalized == t }
    }

    /// Aynı tetik + kapsamdaki açık, temel olmayan diğer atamalar da yeni atamanın yerine geçer (kaldırılır);
    /// açık temel atama burada kalır ve `disableRivals` ile yalnız kapatılır.
    private static func removeOpenRivals(of b: GestureBinding, in list: inout [GestureBinding]) {
        let t = b.trigger.normalized
        list.removeAll { $0.id != b.id && $0.enabled && !$0.isBuiltIn && $0.appBundleID == b.appBundleID && $0.trigger.normalized == t }
    }

    private static func disableRivals(of b: GestureBinding, in list: inout [GestureBinding]) {
        let t = b.trigger.normalized
        for j in list.indices where list[j].id != b.id && list[j].enabled
            && list[j].appBundleID == b.appBundleID && list[j].trigger.normalized == t {
            list[j].enabled = false
        }
    }
}

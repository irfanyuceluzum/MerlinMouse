import Foundation

/// Kayıtlı atamalar üzerinde bir kez uygulanan temizlikler.
public enum BindingMigrations {
    /// Eski sürümden kalan gereksiz 4 parmak atamalarını kaldırır: aynı kapsamda, aynı tür/yön/bölge/tuşla,
    /// aynı eylemli ve aynı `enabled` değerli bir 3 parmak ataması varsa 4 parmak olanı fazladır.
    public static func collapseRedundantFourFinger(_ bindings: [GestureBinding]) -> [GestureBinding] {
        let affected: Set<GestureKind> = [.press, .tap, .doubleTap, .swipe]
        return bindings.filter { b in
            let t = b.trigger.normalized
            guard t.fingers == 4, affected.contains(t.kind) else { return true }
            var three = t
            three.fingers = 3
            let twin = three.normalized
            let hasTwin = bindings.contains {
                $0.id != b.id && $0.appBundleID == b.appBundleID && $0.trigger.normalized == twin
                    && $0.action == b.action && $0.enabled == b.enabled
            }
            return !hasTwin
        }
    }
}

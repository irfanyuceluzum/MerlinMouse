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

    /// Hiç anahtar taşımayan her temel tanım için, genel kapsamda tanımın tetiğine sahip bir atamayı
    /// (önce açık olanı, yoksa ilkini) temel olarak işaretler. Eylem aranmaz; kullanıcı değiştirmiş olabilir.
    public static func tagBuiltIns(_ bindings: [GestureBinding]) -> [GestureBinding] {
        var out = bindings
        for d in DefaultBindings.definitions {
            if out.contains(where: { $0.builtInKey == d.key }) { continue }
            let cands = out.indices.filter {
                out[$0].builtInKey == nil && out[$0].appBundleID == nil && out[$0].trigger.normalized == d.trigger
            }
            guard let pick = cands.first(where: { out[$0].enabled }) ?? cands.first else { continue }
            out[pick].builtInKey = d.key
        }
        return out
    }
}

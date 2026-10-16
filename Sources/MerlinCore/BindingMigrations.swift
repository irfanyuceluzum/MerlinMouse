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
                $0.id != b.id && $0.device == b.device && $0.appBundleID == b.appBundleID
                    && $0.trigger.normalized == twin && $0.action == b.action && $0.enabled == b.enabled
            }
            return !hasTwin
        }
    }

    /// Temel olmayan, kapalı bir atamayı; aynı kapsamda aynı tetik ve aynı eyleme sahip AÇIK ya da TEMEL (açık/kapalı) bir atama varsa kaldırır.
    public static func collapseRedundantDisabledCopies(_ bindings: [GestureBinding]) -> [GestureBinding] {
        bindings.filter { b in
            guard !b.enabled, !b.isBuiltIn else { return true }
            let t = b.trigger.normalized
            let hasOpenTwin = bindings.contains {
                $0.id != b.id && ($0.enabled || $0.isBuiltIn) && $0.device == b.device
                    && $0.appBundleID == b.appBundleID && $0.trigger.normalized == t && $0.action == b.action
            }
            return !hasOpenTwin
        }
    }

    /// Hiç anahtar taşımayan her temel tanım için, genel kapsamda tanımın tetiğine sahip bir atamayı
    /// (önce açık olanı, yoksa ilkini) temel olarak işaretler. Eylem aranmaz; kullanıcı değiştirmiş olabilir.
    /// Temel hareketler yalnız Magic Mouse atamalarıdır.
    public static func tagBuiltIns(_ bindings: [GestureBinding]) -> [GestureBinding] {
        var out = bindings
        for d in DefaultBindings.definitions {
            if out.contains(where: { $0.builtInKey == d.key }) { continue }
            let cands = out.indices.filter {
                out[$0].builtInKey == nil && out[$0].device == .magicMouse && out[$0].appBundleID == nil
                    && out[$0].trigger.normalized == d.trigger
            }
            guard let pick = cands.first(where: { out[$0].enabled }) ?? cands.first else { continue }
            out[pick].builtInKey = d.key
        }
        return out
    }

    /// Sonradan eklenen temel atamaları (`DefaultBindings.laterKeys`: çimdikleme, sol ve sağ kenar) genel
    /// kapsamda, tanımdaki açık/kapalı durumuyla Magic Mouse ataması olarak ekler. O anahtarlı ya da genel
    /// kapsamda aynı tetikli bir Magic Mouse ataması zaten varsa (kapalı da olsa) dokunmaz. `tagBuiltIns`'ten sonra çağrılır.
    public static func addMissingBuiltIns(_ bindings: [GestureBinding]) -> [GestureBinding] {
        var out = bindings
        for key in DefaultBindings.laterKeys {
            guard let d = DefaultBindings.definitions.first(where: { $0.key == key }) else { continue }
            let exists = out.contains {
                $0.builtInKey == d.key
                    || ($0.device == .magicMouse && $0.appBundleID == nil && $0.trigger.normalized == d.trigger)
            }
            if exists { continue }
            out.append(GestureBinding(trigger: d.trigger, action: d.action, enabled: d.defaultEnabled, builtInKey: d.key))
        }
        return out
    }
}

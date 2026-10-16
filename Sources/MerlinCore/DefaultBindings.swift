import Foundation

/// Eski UserDefaults anahtarlarının değerleri.
public struct LegacyFlags: Equatable {
    public var zoneClick: Bool
    public var twoFingerClick: Bool
    public var threeFingerClick: Bool
    public var threeFingerTap: Bool
    public var fnDrag: Bool

    public init(zoneClick: Bool, twoFingerClick: Bool, threeFingerClick: Bool,
                threeFingerTap: Bool, fnDrag: Bool) {
        self.zoneClick = zoneClick
        self.twoFingerClick = twoFingerClick
        self.threeFingerClick = threeFingerClick
        self.threeFingerTap = threeFingerTap
        self.fnDrag = fnDrag
    }
}

/// Temel hareket tanımı: anahtar, varsayılan tetik ve eylem.
public struct BuiltInDefinition: Equatable {
    public let key: String
    public let trigger: Trigger
    public let action: GestureAction
    /// İlk eklendiğinde açık mı (kenar kaydırmalar kapalı gelir).
    public let defaultEnabled: Bool

    public init(key: String, trigger: Trigger, action: GestureAction, defaultEnabled: Bool = true) {
        self.key = key
        self.trigger = trigger
        self.action = action
        self.defaultEnabled = defaultEnabled
    }

    /// Gösterim adı; çeviri tablosundan her çağrıda üretilir.
    public var title: String {
        switch key {
        case "zone-center": return MerlinText.t("Orta bölgeye bas")
        case "two-finger": return MerlinText.t("İki parmakla bas")
        case "three-finger": return MerlinText.t("Üç parmakla bas")
        case "three-finger-tap": return MerlinText.t("Üç parmakla dokun")
        case "fn": return MerlinText.t("Fn + bas")
        case "pinch": return MerlinText.t("İki parmakla çimdikle")
        case "edge-left": return MerlinText.t("Sol kenarda kaydır")
        case "edge-right": return MerlinText.t("Sağ kenarda kaydır")
        default: return key
        }
    }
}

public enum DefaultBindings {
    /// Temel hareketler (sıra sabit). İlk beşi eski ayar bayraklarının karşılığıdır;
    /// sonradan eklenenler (`pinch`, `edge-left`, `edge-right`) yüklemede `BindingMigrations` ile gelir.
    public static let definitions: [BuiltInDefinition] = [
        BuiltInDefinition(key: "zone-center", trigger: Trigger(kind: .press, fingers: 1, zone: .center).normalized,
                          action: .middleClick),
        BuiltInDefinition(key: "two-finger", trigger: Trigger(kind: .press, fingers: 2).normalized,
                          action: .middleClick),
        // "3 ve üzeri": 4 parmak eşleştirmede 3 parmağa geri düşer.
        BuiltInDefinition(key: "three-finger", trigger: Trigger(kind: .press, fingers: 3).normalized,
                          action: .middleClick),
        BuiltInDefinition(key: "three-finger-tap", trigger: Trigger(kind: .tap, fingers: 3).normalized,
                          action: .middleClick),
        BuiltInDefinition(key: "fn", trigger: Trigger(kind: .press, fingers: 0, modifier: .fn).normalized,
                          action: .middleClick),
        BuiltInDefinition(key: "pinch", trigger: Trigger(kind: .pinch, fingers: 2).normalized,
                          action: .zoom(style: .gesture, modifiers: [])),
        BuiltInDefinition(key: "edge-left", trigger: Trigger(kind: .edgeSlide, zone: .leftEdge).normalized,
                          action: .volume, defaultEnabled: false),
        BuiltInDefinition(key: "edge-right", trigger: Trigger(kind: .edgeSlide, zone: .rightEdge).normalized,
                          action: .brightness, defaultEnabled: false),
    ]

    /// Sonradan eklenen temel tanımların anahtarları; yüklemede eksikse `addMissingBuiltIns` ekler.
    public static let laterKeys = ["pinch", "edge-left", "edge-right"]

    /// Eski bayraklı beş kuralın birebir karşılığı; hepsi genel kapsam, orta tıklama.
    /// Sonraki temel hareketler burada yoktur; yüklemede `addMissingBuiltIns` ekler.
    public static func from(legacy: LegacyFlags) -> [GestureBinding] {
        let flags = [legacy.zoneClick, legacy.twoFingerClick, legacy.threeFingerClick,
                     legacy.threeFingerTap, legacy.fnDrag]
        return zip(definitions, flags).map { d, on in
            GestureBinding(trigger: d.trigger, action: d.action, enabled: on, builtInKey: d.key)
        }
    }

    /// Temel atamayı tanımdaki tetik ve eyleme döndürür; id, açık/kapalı ve kapsam korunur.
    public static func resetToDefault(_ binding: GestureBinding) -> GestureBinding {
        guard let key = binding.builtInKey,
              let d = definitions.first(where: { $0.key == key }) else { return binding }
        var out = binding
        out.trigger = d.trigger
        out.action = d.action
        // Temel hareketler Magic Mouse atamalarıdır.
        out.device = .magicMouse
        return out
    }
}

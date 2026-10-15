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
    /// Gösterim adı; çeviri tablosundan her çağrıda üretilir.
    public var title: String {
        switch key {
        case "zone-center": return MerlinText.t("Orta bölgeye bas")
        case "two-finger": return MerlinText.t("İki parmakla bas")
        case "three-finger": return MerlinText.t("Üç parmakla bas")
        case "three-finger-tap": return MerlinText.t("Üç parmakla dokun")
        case "fn": return MerlinText.t("Fn + bas")
        default: return key
        }
    }
}

public enum DefaultBindings {
    /// İlk kurulumdaki beş temel hareket (sıra sabit).
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
    ]

    /// Bugünkü dönüşüm kurallarının birebir karşılığı; hepsi genel kapsam, orta tıklama.
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
        return out
    }
}

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

public enum DefaultBindings {
    /// Bugünkü dönüşüm kurallarının birebir karşılığı; hepsi genel kapsam, orta tıklama.
    public static func from(legacy: LegacyFlags) -> [GestureBinding] {
        func make(_ t: Trigger, _ on: Bool) -> GestureBinding {
            GestureBinding(trigger: t.normalized, action: .middleClick, enabled: on)
        }
        return [
            make(Trigger(kind: .press, fingers: 1, zone: .center), legacy.zoneClick),
            make(Trigger(kind: .press, fingers: 2), legacy.twoFingerClick),
            // "3 ve üzeri": 4 parmak eşleştirmede 3 parmağa geri düşer.
            make(Trigger(kind: .press, fingers: 3), legacy.threeFingerClick),
            make(Trigger(kind: .tap, fingers: 3), legacy.threeFingerTap),
            make(Trigger(kind: .press, fingers: 0, modifier: .fn), legacy.fnDrag),
        ]
    }
}

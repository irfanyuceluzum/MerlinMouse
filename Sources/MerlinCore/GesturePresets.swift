import Foundation

/// Düzenleyicideki hazır hareket kartı.
public struct GesturePreset: Equatable {
    public var title: String
    public var trigger: Trigger

    public init(title: String, trigger: Trigger) {
        self.title = title
        self.trigger = trigger.normalized
    }
}

public enum GesturePresets {
    public static var all: [GesturePreset] { [
        GesturePreset(title: MerlinText.t("Orta bölgeye bas"), trigger: Trigger(kind: .press, fingers: 1, zone: .center)),
        GesturePreset(title: MerlinText.t("Sağ bölgeye bas"), trigger: Trigger(kind: .press, fingers: 1, zone: .right)),
        GesturePreset(title: MerlinText.t("İki parmakla bas"), trigger: Trigger(kind: .press, fingers: 2)),
        GesturePreset(title: MerlinText.t("Üç parmakla bas"), trigger: Trigger(kind: .press, fingers: 3)),
        GesturePreset(title: MerlinText.t("Fn + bas"), trigger: Trigger(kind: .press, modifier: .fn)),
        GesturePreset(title: MerlinText.t("İki parmakla çift dokun"), trigger: Trigger(kind: .doubleTap, fingers: 2)),
        GesturePreset(title: MerlinText.t("Üç parmakla dokun"), trigger: Trigger(kind: .tap, fingers: 3)),
        GesturePreset(title: MerlinText.t("Üç parmakla çift dokun"), trigger: Trigger(kind: .doubleTap, fingers: 3)),
        GesturePreset(title: MerlinText.t("Üç parmakla yukarı kaydır"), trigger: Trigger(kind: .swipe, fingers: 3, direction: .up)),
        GesturePreset(title: MerlinText.t("Üç parmakla aşağı kaydır"), trigger: Trigger(kind: .swipe, fingers: 3, direction: .down)),
        GesturePreset(title: MerlinText.t("Üç parmakla sola kaydır"), trigger: Trigger(kind: .swipe, fingers: 3, direction: .left)),
        GesturePreset(title: MerlinText.t("Üç parmakla sağa kaydır"), trigger: Trigger(kind: .swipe, fingers: 3, direction: .right)),
        GesturePreset(title: MerlinText.t("Arkaya (logoya) dokun"), trigger: Trigger(kind: .tap, fingers: 1, zone: .rear)),
        GesturePreset(title: MerlinText.t("Arkaya (logoya) çift dokun"), trigger: Trigger(kind: .doubleTap, fingers: 1, zone: .rear)),
    ] }
}

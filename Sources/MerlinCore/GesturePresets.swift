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
    public static let all: [GesturePreset] = [
        GesturePreset(title: "Orta bölgeye bas", trigger: Trigger(kind: .press, fingers: 1, zone: .center)),
        GesturePreset(title: "Sağ bölgeye bas", trigger: Trigger(kind: .press, fingers: 1, zone: .right)),
        GesturePreset(title: "İki parmakla bas", trigger: Trigger(kind: .press, fingers: 2)),
        GesturePreset(title: "Üç parmakla bas", trigger: Trigger(kind: .press, fingers: 3)),
        GesturePreset(title: "Fn + bas", trigger: Trigger(kind: .press, modifier: .fn)),
        GesturePreset(title: "İki parmakla çift dokun", trigger: Trigger(kind: .doubleTap, fingers: 2)),
        GesturePreset(title: "Üç parmakla dokun", trigger: Trigger(kind: .tap, fingers: 3)),
        GesturePreset(title: "Üç parmakla çift dokun", trigger: Trigger(kind: .doubleTap, fingers: 3)),
        GesturePreset(title: "Üç parmakla yukarı kaydır", trigger: Trigger(kind: .swipe, fingers: 3, direction: .up)),
        GesturePreset(title: "Üç parmakla aşağı kaydır", trigger: Trigger(kind: .swipe, fingers: 3, direction: .down)),
        GesturePreset(title: "Üç parmakla sola kaydır", trigger: Trigger(kind: .swipe, fingers: 3, direction: .left)),
        GesturePreset(title: "Üç parmakla sağa kaydır", trigger: Trigger(kind: .swipe, fingers: 3, direction: .right)),
    ]
}

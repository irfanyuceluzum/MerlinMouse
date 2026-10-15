import Foundation

/// Düzenleyicide sunulan tetik seçenekleri ve geçersiz birleşimleri düzelten kural.
public enum TriggerOptions {
    /// v1'de "basılı tut" arayüzde yok.
    public static let editableKinds: [GestureKind] = [.press, .tap, .doubleTap, .swipe]

    public static func fingerChoices(kind: GestureKind) -> [Int] {
        switch kind {
        case .press: return [1, 2, 3, 4]
        case .tap: return [2, 3, 4]
        case .doubleTap: return [1, 2, 3, 4]
        case .swipe: return [3, 4]
        case .hold: return []
        }
    }

    /// Bölge yalnız tek parmakta ve tuşsuz tetikte seçilir.
    public static func zoneChoices(kind: GestureKind, fingers: Int, modifier: PressModifier) -> [Zone] {
        guard fingers == 1, modifier == .none else { return [] }
        switch kind {
        case .press: return [.center, .right]
        case .doubleTap: return [.any, .left, .center, .right]
        default: return []
        }
    }

    public static func modifierChoices(kind: GestureKind) -> [PressModifier] {
        kind == .press ? [.none, .fn, .option, .command, .shift] : [.none]
    }

    /// Tetiği geçerli seçeneklere çeker ve normalleştirir.
    public static func sanitize(_ trigger: Trigger) -> Trigger {
        var t = trigger
        if !modifierChoices(kind: t.kind).contains(t.modifier) { t.modifier = .none }
        if t.modifier != .none {
            t.fingers = 0
            t.zone = .any
            return t.normalized
        }
        let fingers = fingerChoices(kind: t.kind)
        if !fingers.isEmpty, !fingers.contains(t.fingers) { t.fingers = fingers[0] }
        let zones = zoneChoices(kind: t.kind, fingers: t.fingers, modifier: t.modifier)
        if zones.isEmpty {
            t.zone = .any
        } else if !zones.contains(t.zone) {
            t.zone = zones[0]
        }
        return t.normalized
    }
}

import Foundation

/// Düzenleyicide sunulan tetik seçenekleri ve geçersiz birleşimleri düzelten kural.
public enum TriggerOptions {
    /// v1'de "basılı tut" arayüzde yok.
    public static let editableKinds: [GestureKind] = [.press, .tap, .doubleTap, .swipe, .pinch, .edgeSlide]

    public static func fingerChoices(kind: GestureKind) -> [Int] {
        switch kind {
        case .press: return [1, 2, 3, 4]
        case .tap: return [1, 2, 3, 4]
        case .doubleTap: return [1, 2, 3, 4]
        case .swipe: return [3, 4]
        case .pinch: return [2]
        case .edgeSlide: return [1]
        case .hold: return []
        }
    }

    /// Bölge yalnız tek parmakta ve tuşsuz tetikte seçilir; kenar şeritleri yalnız kenar kaydırmada.
    public static func zoneChoices(kind: GestureKind, fingers: Int, modifier: PressModifier) -> [Zone] {
        if kind == .edgeSlide { return [.leftEdge, .rightEdge] }
        guard fingers == 1, modifier == .none else { return [] }
        switch kind {
        case .press: return [.center, .right]
        case .tap: return [.rear]
        case .doubleTap: return [.any, .left, .center, .right, .rear]
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

    /// Bölge seçilemiyorsa nedeni; açıklama gerekmiyorsa nil.
    public static func unavailableZoneReason(kind: GestureKind, fingers: Int, modifier: PressModifier) -> String? {
        guard modifier == .none else { return nil }
        switch kind {
        case .press where fingers == 1:
            return MerlinText.t("Sol bölgeye basmak normal sol tıklamadır; değiştirilemez.")
        case .tap where fingers == 1:
            return MerlinText.t("Tek parmakla dokunma yalnız arka (logo) bölgesinde atanabilir; başka yerde fareyi tutarken kazara tetiklenir.")
        case .swipe where fingers < 3:
            return MerlinText.t("Bir ve iki parmakla kaydırma macOS kaydırmasıdır.")
        default:
            return nil
        }
    }

    /// Yeni atama için önerilen tetik: önce çakışmasız, sonra en az engellemeyen aday.
    public static func firstFreeTrigger(among: [GestureBinding], scope: String?,
                                        env: ConflictEnvironment) -> Trigger {
        let candidates: [Trigger] = [
            Trigger(kind: .press, fingers: 1, zone: .right),
            Trigger(kind: .press, fingers: 2),
            Trigger(kind: .press, fingers: 3),
            Trigger(kind: .doubleTap, fingers: 2, zone: .any),
            Trigger(kind: .tap, fingers: 3),
            Trigger(kind: .swipe, fingers: 3, direction: .up),
            Trigger(kind: .swipe, fingers: 3, direction: .down),
            Trigger(kind: .swipe, fingers: 3, direction: .left),
            Trigger(kind: .swipe, fingers: 3, direction: .right),
            Trigger(kind: .press, modifier: .option),
        ].map { $0.normalized }
        var firstNonBlocking: Trigger?
        var firstReplacing: Trigger?
        for t in candidates {
            let probe = GestureBinding(trigger: t, action: .middleClick, appBundleID: scope)
            let conflicts = ConflictChecker.check(probe, among: among, env: env)
            if conflicts.contains(where: { $0.level.blocksSave }) { continue }
            if conflicts.isEmpty { return t }
            if conflicts.contains(where: { $0.level == .replacesDisabled }) {
                if firstReplacing == nil { firstReplacing = t }
                continue
            }
            if firstNonBlocking == nil { firstNonBlocking = t }
        }
        return firstNonBlocking ?? firstReplacing ?? Trigger(kind: .press, fingers: 3)
    }
}

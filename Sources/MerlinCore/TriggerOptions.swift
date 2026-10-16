import Foundation

/// Düzenleyicide sunulan tetik seçenekleri ve geçersiz birleşimleri düzelten kural.
/// Aygıt verilmezse Magic Mouse seçenekleri döner (bugünkü davranış).
public enum TriggerOptions {
    /// v1'de "basılı tut" arayüzde yok.
    public static let editableKinds: [GestureKind] = [.press, .tap, .doubleTap, .swipe, .pinch, .edgeSlide]
    /// Trackpad'de yalnız 3–4 parmakla dokunma, basma ve çift dokunma atanır.
    public static let trackpadKinds: [GestureKind] = [.tap, .press, .doubleTap]

    /// Aygıtın düzenlenebilir türleri.
    public static func kinds(device: InputDeviceKind) -> [GestureKind] {
        device == .trackpad ? trackpadKinds : editableKinds
    }

    public static func fingerChoices(kind: GestureKind, device: InputDeviceKind = .magicMouse) -> [Int] {
        if device == .trackpad { return trackpadKinds.contains(kind) ? [3, 4] : [] }
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
    /// Trackpad'de bölge yoktur.
    public static func zoneChoices(kind: GestureKind, fingers: Int, modifier: PressModifier,
                                   device: InputDeviceKind = .magicMouse) -> [Zone] {
        if device == .trackpad { return [] }
        if kind == .edgeSlide { return [.leftEdge, .rightEdge] }
        guard fingers == 1, modifier == .none else { return [] }
        switch kind {
        case .press: return [.center, .right]
        case .tap: return [.rear]
        case .doubleTap: return [.any, .left, .center, .right, .rear]
        default: return []
        }
    }

    /// Trackpad'de tuşlu basma yoktur.
    public static func modifierChoices(kind: GestureKind, device: InputDeviceKind = .magicMouse) -> [PressModifier] {
        if device == .trackpad { return [.none] }
        return kind == .press ? [.none, .fn, .option, .command, .shift] : [.none]
    }

    /// Tetiği geçerli seçeneklere çeker ve normalleştirir.
    public static func sanitize(_ trigger: Trigger, device: InputDeviceKind = .magicMouse) -> Trigger {
        var t = trigger
        if device == .trackpad, !trackpadKinds.contains(t.kind) { t.kind = trackpadKinds[0] }
        if !modifierChoices(kind: t.kind, device: device).contains(t.modifier) { t.modifier = .none }
        if t.modifier != .none {
            t.fingers = 0
            t.zone = .any
            return t.normalized
        }
        let fingers = fingerChoices(kind: t.kind, device: device)
        if !fingers.isEmpty, !fingers.contains(t.fingers) { t.fingers = fingers[0] }
        let zones = zoneChoices(kind: t.kind, fingers: t.fingers, modifier: t.modifier, device: device)
        if zones.isEmpty {
            t.zone = .any
        } else if !zones.contains(t.zone) {
            t.zone = zones[0]
        }
        return t.normalized
    }

    /// Bölge seçilemiyorsa nedeni; açıklama gerekmiyorsa nil (trackpad'de hiç bölge yok, açıklama da yok).
    public static func unavailableZoneReason(kind: GestureKind, fingers: Int, modifier: PressModifier,
                                             device: InputDeviceKind = .magicMouse) -> String? {
        guard device == .magicMouse, modifier == .none else { return nil }
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
                                        env: ConflictEnvironment,
                                        device: InputDeviceKind = .magicMouse) -> Trigger {
        let candidates: [Trigger]
        let fallback: Trigger
        if device == .trackpad {
            candidates = [
                Trigger(kind: .tap, fingers: 3),
                Trigger(kind: .press, fingers: 3),
                Trigger(kind: .doubleTap, fingers: 3),
                Trigger(kind: .tap, fingers: 4),
                Trigger(kind: .press, fingers: 4),
                Trigger(kind: .doubleTap, fingers: 4),
            ].map { $0.normalized }
            fallback = Trigger(kind: .tap, fingers: 3)
        } else {
            candidates = [
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
            fallback = Trigger(kind: .press, fingers: 3)
        }
        var firstNonBlocking: Trigger?
        var firstReplacing: Trigger?
        for t in candidates {
            let probe = GestureBinding(trigger: t, action: .middleClick, appBundleID: scope, device: device)
            let conflicts = ConflictChecker.check(probe, among: among, env: env)
            if conflicts.contains(where: { $0.level.blocksSave }) { continue }
            if conflicts.isEmpty { return t }
            if conflicts.contains(where: { $0.level == .replacesDisabled }) {
                if firstReplacing == nil { firstReplacing = t }
                continue
            }
            if firstNonBlocking == nil { firstNonBlocking = t }
        }
        return firstNonBlocking ?? firstReplacing ?? fallback
    }
}

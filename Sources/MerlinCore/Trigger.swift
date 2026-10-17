import Foundation

/// Hareketin türü.
public enum GestureKind: String, Codable, Hashable, CaseIterable {
    case press, hold, tap, doubleTap, swipe
    /// İki parmakla çimdikleme (her zaman 2 parmak, bölgesiz).
    case pinch
    /// Farenin sol ya da sağ kenar şeridinde tek parmakla yukarı / aşağı kaydırma (adım eylemleri).
    case edgeSlide
}

/// Tek parmakla basılan bölge. `leftEdge` / `rightEdge` yalnız kenar kaydırmanın şerididir; `corner…` yalnız
/// trackpad'de tek parmakla basmanın köşeleridir. Fare için `Zone.classify` bunları hiç döndürmez.
public enum Zone: String, Codable, Hashable, CaseIterable {
    case any, left, center, right, rear
    case leftEdge, rightEdge
    case cornerTopLeft, cornerTopRight, cornerBottomLeft, cornerBottomRight

    /// Kenar kaydırma şeridi mi?
    public var isEdge: Bool { self == .leftEdge || self == .rightEdge }

    /// Trackpad köşesi mi?
    public var isCorner: Bool {
        switch self {
        case .cornerTopLeft, .cornerTopRight, .cornerBottomLeft, .cornerBottomRight: return true
        default: return false
        }
    }

    /// Trackpad köşeleri, seçicideki sırayla.
    public static let corners: [Zone] = [.cornerTopLeft, .cornerTopRight, .cornerBottomLeft, .cornerBottomRight]

    /// Arayüzde gösterilen ad.
    public var displayName: String {
        switch self {
        case .any: return MerlinText.t("Her yer")
        case .left: return MerlinText.t("Sol")
        case .center: return MerlinText.t("Orta")
        case .right: return MerlinText.t("Sağ")
        case .rear: return MerlinText.t("Arka (logo)")
        case .leftEdge: return MerlinText.t("Sol kenar")
        case .rightEdge: return MerlinText.t("Sağ kenar")
        case .cornerTopLeft: return MerlinText.t("Sol üst köşe")
        case .cornerTopRight: return MerlinText.t("Sağ üst köşe")
        case .cornerBottomLeft: return MerlinText.t("Sol alt köşe")
        case .cornerBottomRight: return MerlinText.t("Sağ alt köşe")
        }
    }
}

/// Kaydırma yönü; "up" farenin önüne doğrudur.
public enum SwipeDirection: String, Codable, Hashable, CaseIterable {
    case up, down, left, right
}

/// Tuşlu tetiklerde basılı tutulan düzenleyici (control yok).
public enum PressModifier: String, Codable, Hashable, CaseIterable {
    case none, fn, option, command, shift
}

public struct Trigger: Codable, Hashable {
    public var kind: GestureKind
    /// 0 = herhangi (yalnız tuşlu tetiklerde).
    public var fingers: Int
    public var zone: Zone
    public var direction: SwipeDirection
    public var modifier: PressModifier

    public init(kind: GestureKind,
                fingers: Int = 1,
                zone: Zone = .any,
                direction: SwipeDirection = .up,
                modifier: PressModifier = .none) {
        self.kind = kind
        self.fingers = fingers
        self.zone = zone
        self.direction = direction
        self.modifier = modifier
    }

    /// Anlamsız alanları sabit değere çeker; eşleştirme bu biçimle yapılır.
    public var normalized: Trigger {
        var t = self
        if t.kind == .pinch {
            t.fingers = 2
            t.zone = .any
            t.direction = .up
            t.modifier = .none
            return t
        }
        if t.kind == .edgeSlide {
            t.fingers = 1
            if !t.zone.isEdge { t.zone = .leftEdge }
            t.direction = .up
            t.modifier = .none
            return t
        }
        // Kenar şeritleri yalnız kenar kaydırmada, köşeler yalnız (tek parmak, tuşsuz) basmada anlamlıdır.
        if t.zone.isEdge { t.zone = .any }
        if t.zone.isCorner, t.kind != .press && t.kind != .hold { t.zone = .any }
        if t.kind != .swipe { t.direction = .up }
        if t.fingers != 1 { t.zone = .any }
        if t.kind != .press && t.kind != .hold { t.modifier = .none }
        if t.modifier != .none {
            t.fingers = 0
            t.zone = .any
        }
        return t
    }

    public var title: String {
        let t = normalized
        if t.modifier != .none {
            // Tuşlu tetikler yalnız basma / basılı tutma olabilir (normalized).
            let hold = t.kind == .hold
            switch t.modifier {
            case .fn: return hold ? MerlinText.t("Fn + basılı tut") : MerlinText.t("Fn + bas")
            case .option: return hold ? MerlinText.t("Option + basılı tut") : MerlinText.t("Option + bas")
            case .command: return hold ? MerlinText.t("Command + basılı tut") : MerlinText.t("Command + bas")
            case .shift: return hold ? MerlinText.t("Shift + basılı tut") : MerlinText.t("Shift + bas")
            case .none: break
            }
        }
        // Dil yapıları farklı olduğundan başlık, her tür için "%@" ön ifadeli tam cümle şablonudur.
        let phrase: String
        if t.fingers == 1 {
            switch t.zone {
            // Kenar şeritleri kenar kaydırma dışında normalleştirmede "her yer" olur.
            case .any, .leftEdge, .rightEdge: phrase = MerlinText.t("Tek parmakla")
            case .left: phrase = MerlinText.t("Sol bölgeye")
            case .center: phrase = MerlinText.t("Orta bölgeye")
            case .right: phrase = MerlinText.t("Sağ bölgeye")
            case .rear: phrase = MerlinText.t("Arkaya")
            case .cornerTopLeft: phrase = MerlinText.t("Sol üst köşeye")
            case .cornerTopRight: phrase = MerlinText.t("Sağ üst köşeye")
            case .cornerBottomLeft: phrase = MerlinText.t("Sol alt köşeye")
            case .cornerBottomRight: phrase = MerlinText.t("Sağ alt köşeye")
            }
        } else {
            switch t.fingers {
            case 0: phrase = MerlinText.t("Herhangi bir parmakla")
            case 2: phrase = MerlinText.t("İki parmakla")
            case 3: phrase = MerlinText.t("Üç parmakla")
            case 4: phrase = MerlinText.t("Dört parmakla")
            case 5: phrase = MerlinText.t("Beş parmakla")
            default: phrase = MerlinText.f("%d parmakla", t.fingers)
            }
        }
        switch t.kind {
        case .press: return MerlinText.f("%@ bas", phrase)
        case .hold: return MerlinText.f("%@ basılı tut", phrase)
        case .tap: return MerlinText.f("%@ dokun", phrase)
        case .doubleTap: return MerlinText.f("%@ çift dokun", phrase)
        case .swipe:
            switch t.direction {
            case .up: return MerlinText.f("%@ yukarı kaydır", phrase)
            case .down: return MerlinText.f("%@ aşağı kaydır", phrase)
            case .left: return MerlinText.f("%@ sola kaydır", phrase)
            case .right: return MerlinText.f("%@ sağa kaydır", phrase)
            }
        case .pinch: return MerlinText.t("İki parmakla çimdikle")
        case .edgeSlide:
            return t.zone == .rightEdge ? MerlinText.t("Sağ kenarda kaydır") : MerlinText.t("Sol kenarda kaydır")
        }
    }
}

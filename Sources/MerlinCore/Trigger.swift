import Foundation

/// Hareketin türü.
public enum GestureKind: String, Codable, Hashable, CaseIterable {
    case press, hold, tap, doubleTap, swipe
}

/// Tek parmakla basılan bölge.
public enum Zone: String, Codable, Hashable, CaseIterable {
    case any, left, center, right, rear

    /// Arayüzde gösterilen ad.
    public var displayName: String {
        switch self {
        case .any: return "Her yer"
        case .left: return "Sol"
        case .center: return "Orta"
        case .right: return "Sağ"
        case .rear: return "Arka (logo)"
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
        let verb: String
        switch t.kind {
        case .press: verb = "bas"
        case .hold: verb = "basılı tut"
        case .tap: verb = "dokun"
        case .doubleTap: verb = "çift dokun"
        case .swipe:
            switch t.direction {
            case .up: verb = "yukarı kaydır"
            case .down: verb = "aşağı kaydır"
            case .left: verb = "sola kaydır"
            case .right: verb = "sağa kaydır"
            }
        }
        if t.modifier != .none {
            let name: String
            switch t.modifier {
            case .fn: name = "Fn"
            case .option: name = "Option"
            case .command: name = "Command"
            case .shift: name = "Shift"
            case .none: name = ""
            }
            return "\(name) + \(verb)"
        }
        let prefix: String
        if t.fingers == 1 {
            switch t.zone {
            case .any: prefix = "Tek parmakla"
            case .left: prefix = "Sol bölgeye"
            case .center: prefix = "Orta bölgeye"
            case .right: prefix = "Sağ bölgeye"
            case .rear: prefix = "Arkaya"
            }
        } else {
            switch t.fingers {
            case 0: prefix = "Herhangi bir parmakla"
            case 2: prefix = "İki parmakla"
            case 3: prefix = "Üç parmakla"
            case 4: prefix = "Dört parmakla"
            case 5: prefix = "Beş parmakla"
            default: prefix = "\(t.fingers) parmakla"
            }
        }
        return "\(prefix) \(verb)"
    }
}

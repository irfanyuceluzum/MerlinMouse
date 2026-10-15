import Foundation

public struct KeyCombo: Codable, Hashable {
    public var keyCode: UInt16
    /// "command", "option", "control", "shift", "fn"
    public var modifiers: [String]
    public var display: String

    public init(keyCode: UInt16, modifiers: [String], display: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.display = display
    }
}

public enum SystemAction: String, Codable, Hashable, CaseIterable {
    case missionControl, appWindows, showDesktop, screenshot, lockScreen, spotlight

    public var keyCombo: KeyCombo {
        switch self {
        case .missionControl: return KeyCombo(keyCode: 126, modifiers: ["control"], display: "⌃↑")
        case .appWindows: return KeyCombo(keyCode: 125, modifiers: ["control"], display: "⌃↓")
        case .showDesktop: return KeyCombo(keyCode: 103, modifiers: [], display: "F11")
        case .screenshot: return KeyCombo(keyCode: 23, modifiers: ["command", "shift"], display: "⌘⇧5")
        case .lockScreen: return KeyCombo(keyCode: 12, modifiers: ["control", "command"], display: "⌃⌘Q")
        case .spotlight: return KeyCombo(keyCode: 49, modifiers: ["command"], display: "⌘Space")
        }
    }

    public var title: String {
        switch self {
        case .missionControl: return "Mission Control"
        case .appWindows: return "Uygulama pencereleri"
        case .showDesktop: return "Masaüstünü göster"
        case .screenshot: return "Ekran görüntüsü"
        case .lockScreen: return "Ekranı kilitle"
        case .spotlight: return "Spotlight"
        }
    }
}

public enum GestureAction: Hashable {
    case middleClick
    case back
    case forward
    case shortcut(KeyCombo)
    case system(SystemAction)
    case openApp(path: String, name: String)
    case runShortcut(name: String)

    public var title: String {
        switch self {
        case .middleClick: return "Orta tıklama"
        case .back: return "Geri"
        case .forward: return "İleri"
        case .shortcut(let combo): return "Kısayol \(combo.display)"
        case .system(let s): return s.title
        case .openApp(_, let name): return "\(name) uygulamasını aç"
        case .runShortcut(let name): return "Kısayolu çalıştır: \(name)"
        }
    }

    public var isMouseButton: Bool { buttonNumber != nil }

    /// Fare düğmesi numarası (orta 2, geri 3, ileri 4); düğme değilse nil.
    public var buttonNumber: Int? {
        switch self {
        case .middleClick: return 2
        case .back: return 3
        case .forward: return 4
        default: return nil
        }
    }
}

// Elle Codable: `{"type":"shortcut", ...alanlar}`; `type` ayrımcı.
extension GestureAction: Codable {
    private enum Keys: String, CodingKey {
        case type, keyCode, modifiers, display, system, path, name
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "middleClick": self = .middleClick
        case "back": self = .back
        case "forward": self = .forward
        case "shortcut":
            self = .shortcut(KeyCombo(keyCode: try c.decode(UInt16.self, forKey: .keyCode),
                                      modifiers: try c.decode([String].self, forKey: .modifiers),
                                      display: try c.decode(String.self, forKey: .display)))
        case "system":
            self = .system(try c.decode(SystemAction.self, forKey: .system))
        case "openApp":
            self = .openApp(path: try c.decode(String.self, forKey: .path),
                            name: try c.decode(String.self, forKey: .name))
        case "runShortcut":
            self = .runShortcut(name: try c.decode(String.self, forKey: .name))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c,
                                                   debugDescription: "Bilinmeyen eylem türü: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .middleClick: try c.encode("middleClick", forKey: .type)
        case .back: try c.encode("back", forKey: .type)
        case .forward: try c.encode("forward", forKey: .type)
        case .shortcut(let combo):
            try c.encode("shortcut", forKey: .type)
            try c.encode(combo.keyCode, forKey: .keyCode)
            try c.encode(combo.modifiers, forKey: .modifiers)
            try c.encode(combo.display, forKey: .display)
        case .system(let s):
            try c.encode("system", forKey: .type)
            try c.encode(s, forKey: .system)
        case .openApp(let path, let name):
            try c.encode("openApp", forKey: .type)
            try c.encode(path, forKey: .path)
            try c.encode(name, forKey: .name)
        case .runShortcut(let name):
            try c.encode("runShortcut", forKey: .type)
            try c.encode(name, forKey: .name)
        }
    }
}

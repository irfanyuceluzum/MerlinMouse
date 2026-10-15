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
        case .missionControl: return MerlinText.t("Mission Control")
        case .appWindows: return MerlinText.t("Uygulama pencereleri")
        case .showDesktop: return MerlinText.t("Masaüstünü göster")
        case .screenshot: return MerlinText.t("Ekran görüntüsü")
        case .lockScreen: return MerlinText.t("Ekranı kilitle")
        case .spotlight: return MerlinText.t("Spotlight")
        }
    }
}

/// Yakınlaştırmanın uygulamaya nasıl gönderileceği.
public enum ZoomStyle: String, Codable, CaseIterable {
    /// Trackpad büyütme hareketi (yalnız içerik büyür).
    case gesture
    /// Fare tekerleği (isteğe bağlı düzenleyicilerle, örn. ⌃ + tekerlek).
    case wheel
    /// ⌘+ / ⌘− (sayısal tuş takımı).
    case keys
}

public enum GestureAction: Hashable {
    case middleClick
    case back
    case forward
    case shortcut(KeyCombo)
    case system(SystemAction)
    case openApp(path: String, name: String)
    case runShortcut(name: String)
    /// Çimdiklemeyle yakınlaştırma / uzaklaştırma (yalnız pinch tetiğiyle). Düzenleyiciler yalnız
    /// `wheel` yönteminde anlamlıdır; diğer yöntemlerde normalleştirmede boşaltılır.
    case zoom(style: ZoomStyle, modifiers: [String])
    /// Düzenleyici tuşlarla birlikte orta tuş (basma, sürükleme, bırakma); adlar `middleDragModifierOrder`'dan.
    case middleDrag(modifiers: [String])

    /// Düzenleyicili orta tuşta izinli adlar, gösterim sırasıyla (⌃⌥⇧⌘).
    public static let middleDragModifierOrder = ["control", "option", "shift", "command"]

    /// Yalnız izinli, tekrarsız ve ⌃⌥⇧⌘ sırasında düzenleyiciler.
    public static func normalizedModifiers(_ names: [String]) -> [String] {
        middleDragModifierOrder.filter { names.contains($0) }
    }

    /// Düzenleyici adının simgesi (⌃ ⌥ ⇧ ⌘); bilinmeyen ad için boş.
    public static func modifierSymbol(_ name: String) -> String {
        switch name {
        case "control": return "⌃"
        case "option": return "⌥"
        case "shift": return "⇧"
        case "command": return "⌘"
        default: return ""
        }
    }

    /// Düzenleyicilerin sıralı simgeleri, örn. "⌃⇧".
    public static func modifierSymbols(_ names: [String]) -> String {
        normalizedModifiers(names).map(modifierSymbol).joined()
    }

    /// Yakınlaştırma yönteminde anlamlı düzenleyiciler: yalnız `wheel`'de normalleştirilmiş liste, diğerlerinde boş.
    public static func zoomModifiers(_ names: [String], style: ZoomStyle) -> [String] {
        style == .wheel ? normalizedModifiers(names) : []
    }

    /// `.middleDrag` ve `.zoom` (yalnız `wheel`) için normalleştirilmiş düzenleyiciler; diğer eylemlerde boş.
    public var normalizedModifiers: [String] {
        switch self {
        case .middleDrag(let mods): return Self.normalizedModifiers(mods)
        case .zoom(let style, let mods): return Self.zoomModifiers(mods, style: style)
        default: return []
        }
    }

    /// Yakınlaştırmanın yöntemi; yakınlaştırma değilse nil.
    public var zoomStyle: ZoomStyle? {
        if case .zoom(let style, _) = self { return style }
        return nil
    }

    /// Eylem yakınlaştırma mı (düzenleyiciden bağımsız)?
    public var isZoom: Bool {
        if case .zoom = self { return true }
        return false
    }

    public var title: String {
        switch self {
        case .zoom(let style, let mods):
            switch style {
            case .gesture: return MerlinText.t("Yakınlaştır / uzaklaştır")
            case .keys: return MerlinText.t("Yakınlaştır / uzaklaştır (⌘+ / ⌘−)")
            case .wheel:
                let symbols = Self.modifierSymbols(mods)
                return symbols.isEmpty ? MerlinText.t("Yakınlaştır / uzaklaştır (tekerlek)")
                    : MerlinText.f("Yakınlaştır / uzaklaştır (%@ + tekerlek)", symbols)
            }
        case .middleDrag(let mods):
            let symbols = Self.modifierSymbols(mods)
            return symbols.isEmpty ? MerlinText.t("Düzenleyicili orta tuş") : MerlinText.f("Orta tuş + %@", symbols)
        case .middleClick: return MerlinText.t("Orta tıklama")
        case .back: return MerlinText.t("Geri")
        case .forward: return MerlinText.t("İleri")
        case .shortcut(let combo): return MerlinText.f("Kısayol %@", combo.display)
        case .system(let s): return s.title
        case .openApp(_, let name): return MerlinText.f("%@ uygulamasını aç", name)
        case .runShortcut(let name): return MerlinText.f("Kısayolu çalıştır: %@", name)
        }
    }

    public var isMouseButton: Bool { buttonNumber != nil }

    /// Fare düğmesi numarası (orta 2, geri 3, ileri 4); düğme değilse nil.
    public var buttonNumber: Int? {
        switch self {
        case .middleClick, .middleDrag: return 2
        case .back: return 3
        case .forward: return 4
        default: return nil
        }
    }
}

// Elle Codable: `{"type":"shortcut", ...alanlar}`; `type` ayrımcı.
extension GestureAction: Codable {
    private enum Keys: String, CodingKey {
        case type, keyCode, modifiers, display, system, path, name, style
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
        case "zoom":
            // Kart 24 dosyalarında düzenleyici alanı yok: boş liste. Kart 26 öncesinde `style` yok:
            // düzenleyicisiz kayıt trackpad hareketi, düzenleyicili kayıt (örn. CHITUBOX ⌃) tekerlek olarak kalır.
            let mods = Self.normalizedModifiers(try c.decodeIfPresent([String].self, forKey: .modifiers) ?? [])
            let style: ZoomStyle
            if let raw = try c.decodeIfPresent(String.self, forKey: .style) {
                guard let s = ZoomStyle(rawValue: raw) else {
                    throw DecodingError.dataCorruptedError(forKey: .style, in: c,
                                                           debugDescription: "Bilinmeyen yakınlaştırma yöntemi: \(raw)")
                }
                style = s
            } else {
                style = mods.isEmpty ? .gesture : .wheel
            }
            self = .zoom(style: style, modifiers: Self.zoomModifiers(mods, style: style))
        case "middleDrag":
            self = .middleDrag(modifiers: Self.normalizedModifiers(try c.decode([String].self, forKey: .modifiers)))
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
        case .zoom(let style, let mods):
            try c.encode("zoom", forKey: .type)
            if style != .gesture { try c.encode(style.rawValue, forKey: .style) }
            let normalized = Self.zoomModifiers(mods, style: style)
            if !normalized.isEmpty { try c.encode(normalized, forKey: .modifiers) }
        case .middleDrag(let mods):
            try c.encode("middleDrag", forKey: .type)
            try c.encode(Self.normalizedModifiers(mods), forKey: .modifiers)
        }
    }
}

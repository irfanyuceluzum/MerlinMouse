import Foundation

/// BetterTouchTool'dan gelen tek bir Magic Mouse ataması (yalnız okunur).
public struct BTTItem: Hashable, Identifiable {
    /// Taramadaki sıra numarası (listede kimlik olarak kullanılır).
    public var id: Int
    public var description: String
    public var actionName: String
    /// nil = Global.
    public var appName: String?
    public var enabled: Bool
    public var trigger: Trigger?
    public var action: GestureAction?
    /// Devralınamama nedeni; nil ise (trigger ve action varsa) devralınabilir.
    public var reason: String?

    public init(id: Int = 0, description: String, actionName: String, appName: String? = nil,
                enabled: Bool = true, trigger: Trigger? = nil, action: GestureAction? = nil,
                reason: String? = nil) {
        self.id = id
        self.description = description
        self.actionName = actionName
        self.appName = appName
        self.enabled = enabled
        self.trigger = trigger
        self.action = action
        self.reason = reason
    }
}

public struct BTTScan: Equatable {
    public var magicMouse: [BTTItem]
    /// BTT sınıf adı → sayı (Magic Mouse dışındakiler).
    public var otherCounts: [String: Int]

    public init(magicMouse: [BTTItem] = [], otherCounts: [String: Int] = [:]) {
        self.magicMouse = magicMouse
        self.otherCounts = otherCounts
    }
}

public enum BTTImportError: Error, Equatable {
    case invalidFormat
}

public enum BTTImport {
    static let otherClassKey = "BTTTriggerTypeOtherTriggers"

    public static func parse(_ data: Data) throws -> BTTScan {
        let obj: Any
        do { obj = try JSONSerialization.jsonObject(with: data) } catch { throw BTTImportError.invalidFormat }
        guard let array = obj as? [Any] else { throw BTTImportError.invalidFormat }

        var scan = BTTScan()
        for case let dict as [String: Any] in array {
            let cls = dict["BTTTriggerClass"] as? String
            let hasType = dict["BTTTriggerType"] != nil
            let actions = dict["BTTActionsToExecute"] as? [Any] ?? []
            let hasAction = !actions.isEmpty || dict["BTTPredefinedActionType"] != nil
                || (dict["BTTPredefinedActionName"] as? String) != nil
            // Klasör / boş girdi.
            guard hasType, hasAction else { continue }

            if cls == "BTTTriggerTypeMagicMouse" {
                let item = makeItem(dict, actions: actions, id: scan.magicMouse.count)
                scan.magicMouse.append(item)
            } else {
                scan.otherCounts[cls ?? otherClassKey, default: 0] += 1
            }
        }
        return scan
    }

    public static func importable(_ item: BTTItem) -> Bool {
        item.trigger != nil && item.action != nil && item.reason == nil
    }

    /// Türkçe sınıf adı.
    public static func className(_ cls: String) -> String {
        let l = cls.lowercased()
        if l.contains("touchpad") || l.contains("trackpad") { return MerlinText.t("Trackpad") }
        if l.contains("keyboard") { return MerlinText.t("Klavye kısayolu") }
        if l.contains("touchbar") { return MerlinText.t("Touch Bar") }
        return MerlinText.t("Diğer tetikleyiciler")
    }

    // MARK: Ayrıştırma

    private static func makeItem(_ d: [String: Any], actions: [Any], id: Int) -> BTTItem {
        let typeNum = number(d["BTTTriggerType"])
        var desc = (d["BTTTriggerTypeDescriptionReadOnly"] as? String) ?? ""
        if desc.isEmpty, let n = typeNum {
            switch n {
            case 20: desc = "2 Finger Click"
            case 21: desc = "3 Finger Click"
            default: break
            }
        }

        let first = actions.first as? [String: Any]
        let actionType = number(d["BTTPredefinedActionType"]) ?? first.flatMap { number($0["BTTPredefinedActionType"]) }
        let actionName = (d["BTTPredefinedActionName"] as? String)
            ?? (first?["BTTPredefinedActionName"] as? String) ?? ""

        let rawApp = (d["BTTBelongsToApp"] as? String) ?? "Global"
        let app: String? = (rawApp.isEmpty || rawApp == "Global") ? nil : rawApp
        let enabled = flag(d["BTTEnabled2"]) ?? flag(d["BTTEnabled"]) ?? true

        var reason: String?
        let (trigger, triggerReason) = mapTrigger(desc)
        var action: GestureAction?
        if actionType == 1 || actionName.contains("Middle Click") {
            action = .middleClick
        }
        if let app {
            reason = MerlinText.f("Uygulamaya özel BTT atamaları elle eklenmeli (%@)", app)
        } else if let triggerReason {
            reason = triggerReason
        } else if action == nil {
            reason = MerlinText.f("Bu eylem henüz devralınamıyor ('%@')", actionName)
        }
        return BTTItem(id: id, description: desc, actionName: actionName, appName: app, enabled: enabled,
                       trigger: trigger, action: action, reason: reason)
    }

    private static func mapTrigger(_ desc: String) -> (Trigger?, String?) {
        let unknown = MerlinText.t("Bu hareket henüz devralınamıyor")
        let l = desc.lowercased()
        guard let re = try? NSRegularExpression(
            pattern: #"^(\d+)\s*finger\s+(click|tap|double[- ]?tap|swipe\s+(up|down|left|right))$"#),
              let m = re.firstMatch(in: l, range: NSRange(l.startIndex..., in: l)),
              let nr = Range(m.range(at: 1), in: l), let n = Int(l[nr]),
              let kr = Range(m.range(at: 2), in: l) else { return (nil, unknown) }
        let kind = String(l[kr])
        if kind == "click" {
            if n == 1 { return (nil, MerlinText.t("Tek parmakla tıklama normal sol tıklamadır")) }
            guard (2...4).contains(n) else { return (nil, unknown) }
            return (Trigger(kind: .press, fingers: n), nil)
        }
        guard (1...5).contains(n) else { return (nil, unknown) }
        if kind == "tap" { return (Trigger(kind: .tap, fingers: n), nil) }
        if kind.hasPrefix("double") { return (Trigger(kind: .doubleTap, fingers: n), nil) }
        if n < 3 { return (nil, MerlinText.t("Bir ve iki parmakla kaydırma macOS kaydırmasıdır")) }
        let dir: SwipeDirection
        if let dr = Range(m.range(at: 3), in: l) {
            switch l[dr] {
            case "up": dir = .up
            case "down": dir = .down
            case "left": dir = .left
            default: dir = .right
            }
        } else { return (nil, unknown) }
        return (Trigger(kind: .swipe, fingers: n, direction: dir), nil)
    }

    private static func number(_ v: Any?) -> Int? {
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String { return Int(s) }
        return nil
    }

    private static func flag(_ v: Any?) -> Bool? {
        if let n = v as? NSNumber { return n.intValue != 0 }
        if let s = v as? String { return !(s == "0" || s.lowercased() == "false") }
        return nil
    }
}

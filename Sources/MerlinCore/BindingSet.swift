import Foundation

public struct GestureBinding: Codable, Hashable {
    public var id: UUID
    public var trigger: Trigger
    public var action: GestureAction
    public var enabled: Bool
    public var appBundleID: String?
    public var appName: String?

    public init(id: UUID = UUID(),
                trigger: Trigger,
                action: GestureAction,
                enabled: Bool = true,
                appBundleID: String? = nil,
                appName: String? = nil) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.enabled = enabled
        self.appBundleID = appBundleID
        self.appName = appName
    }
}

/// Dosya kökü: `{"version":1,"bindings":[…]}`. Çözülemeyen elemanlar `preserved`
/// içinde ham JSON olarak tutulur ve yazarken aynen geri yazılır.
public struct BindingSet: Codable, Equatable {
    public var version: Int
    public var bindings: [GestureBinding]
    public var preserved: [JSONValue]

    public init(version: Int = 1, bindings: [GestureBinding] = [], preserved: [JSONValue] = []) {
        self.version = version
        self.bindings = bindings
        self.preserved = preserved
    }

    private enum Keys: String, CodingKey { case version, bindings }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        var list = try c.nestedUnkeyedContainer(forKey: .bindings)
        var good: [GestureBinding] = []
        var kept: [JSONValue] = []
        let enc = JSONEncoder()
        let dec = JSONDecoder()
        while !list.isAtEnd {
            let raw = try list.decode(JSONValue.self)
            if let data = try? enc.encode(raw),
               let b = try? dec.decode(GestureBinding.self, from: data) {
                good.append(b)
            } else {
                kept.append(raw)
            }
        }
        bindings = good
        preserved = kept
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(version, forKey: .version)
        var list = c.nestedUnkeyedContainer(forKey: .bindings)
        for b in bindings { try list.encode(b) }
        for p in preserved { try list.encode(p) }
    }
}

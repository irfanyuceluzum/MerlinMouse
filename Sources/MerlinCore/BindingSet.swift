import Foundation

public struct GestureBinding: Codable, Hashable {
    public var id: UUID
    public var trigger: Trigger
    public var action: GestureAction
    public var enabled: Bool
    public var appBundleID: String?
    public var appName: String?
    /// Temel (ilk kurulum) hareket anahtarı; nil = kullanıcının eklediği atama.
    public var builtInKey: String?

    public var isBuiltIn: Bool { builtInKey != nil }

    public init(id: UUID = UUID(),
                trigger: Trigger,
                action: GestureAction,
                enabled: Bool = true,
                appBundleID: String? = nil,
                appName: String? = nil,
                builtInKey: String? = nil) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.enabled = enabled
        self.appBundleID = appBundleID
        self.appName = appName
        self.builtInKey = builtInKey
    }

    private enum CodingKeys: String, CodingKey {
        case id, trigger, action, enabled, appBundleID, appName, builtInKey
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        trigger = try c.decode(Trigger.self, forKey: .trigger)
        action = try c.decode(GestureAction.self, forKey: .action)
        enabled = try c.decode(Bool.self, forKey: .enabled)
        appBundleID = try c.decodeIfPresent(String.self, forKey: .appBundleID)
        appName = try c.decodeIfPresent(String.self, forKey: .appName)
        builtInKey = try c.decodeIfPresent(String.self, forKey: .builtInKey)
    }
}

/// Profil sayfasına eklenen uygulama (ataması olmasa da listede kalır).
public struct ProfileApp: Codable, Hashable {
    public var bundleID: String
    public var name: String

    public init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }
}

/// Dosya kökü: `{"version":1,"bindings":[…]}`. Çözülemeyen elemanlar `preserved`
/// içinde ham JSON olarak tutulur ve yazarken aynen geri yazılır.
public struct BindingSet: Codable, Equatable {
    public var version: Int
    public var bindings: [GestureBinding]
    public var preserved: [JSONValue]
    public var profiles: [ProfileApp]

    public init(version: Int = 1, bindings: [GestureBinding] = [], preserved: [JSONValue] = [],
                profiles: [ProfileApp] = []) {
        self.profiles = profiles
        self.version = version
        self.bindings = bindings
        self.preserved = preserved
    }

    private enum Keys: String, CodingKey { case version, bindings, profiles }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        profiles = try c.decodeIfPresent([ProfileApp].self, forKey: .profiles) ?? []
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
        try c.encode(profiles, forKey: .profiles)
        var list = c.nestedUnkeyedContainer(forKey: .bindings)
        for b in bindings { try list.encode(b) }
        for p in preserved { try list.encode(p) }
    }
}

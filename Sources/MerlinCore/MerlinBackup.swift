import Foundation

/// Yedeklenen kullanıcı ayarları; hepsi opsiyoneldir, eksik alanlar geri yüklemede atlanır.
public struct BackupSettings: Codable, Equatable {
    public var zoneLayout: ZoneLayout?
    public var appearance: String?
    public var language: String?
    public var flipY: Bool?
    public var blockScrollWhileDragging: Bool?
    public var calm3DScroll: Bool?
    public var batteryAlertsEnabled: Bool?

    public init(zoneLayout: ZoneLayout? = nil, appearance: String? = nil, language: String? = nil,
                flipY: Bool? = nil, blockScrollWhileDragging: Bool? = nil, calm3DScroll: Bool? = nil,
                batteryAlertsEnabled: Bool? = nil) {
        self.zoneLayout = zoneLayout
        self.appearance = appearance
        self.language = language
        self.flipY = flipY
        self.blockScrollWhileDragging = blockScrollWhileDragging
        self.calm3DScroll = calm3DScroll
        self.batteryAlertsEnabled = batteryAlertsEnabled
    }
}

public enum MerlinBackupError: LocalizedError, Equatable {
    case notABackup
    case futureVersion(Int)

    public var errorDescription: String? {
        switch self {
        case .notABackup:
            return MerlinText.t("Bu dosya bir Merlin Mouse yedeği değil.")
        case .futureVersion(let v):
            return MerlinText.f("Bu yedek daha yeni bir sürümle oluşturulmuş (sürüm %lld). Uygulamayı güncelle.", v)
        }
    }
}

/// Atamalar ve ayarların tek dosyalık yedeği (`.merlinbackup`, JSON).
public struct MerlinBackup: Codable, Equatable {
    public static let currentVersion = 1
    public static let appName = "Merlin Mouse"

    public var version: Int
    public var createdAt: Date
    public var app: String
    public var bindings: BindingSet
    public var settings: BackupSettings

    public init(version: Int = MerlinBackup.currentVersion, createdAt: Date = Date(),
                app: String = MerlinBackup.appName, bindings: BindingSet, settings: BackupSettings) {
        self.version = version
        self.createdAt = createdAt
        self.app = app
        self.bindings = bindings
        self.settings = settings
    }

    public func encode() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(self)
    }

    public static func decode(_ data: Data) throws -> MerlinBackup {
        struct Header: Decodable { var version: Int?; var app: String? }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        guard let header = try? dec.decode(Header.self, from: data),
              header.app == appName, let version = header.version else {
            throw MerlinBackupError.notABackup
        }
        if version > currentVersion { throw MerlinBackupError.futureVersion(version) }
        do {
            return try dec.decode(MerlinBackup.self, from: data)
        } catch {
            throw MerlinBackupError.notABackup
        }
    }
}

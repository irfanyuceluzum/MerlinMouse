import Foundation

/// Bağlı dokunma aygıtlarının sayısı; aygıtı olmayan türün ayarları pasif kalır.
public struct DevicePresence: Equatable {
    public var mice: Int
    public var trackpads: Int
    /// Trackpad'lerden biri dahili mi (MacBook).
    public var builtInTrackpad: Bool

    public init(mice: Int = 0, trackpads: Int = 0, builtInTrackpad: Bool = false) {
        self.mice = mice
        self.trackpads = trackpads
        self.builtInTrackpad = builtInTrackpad
    }

    public static let none = DevicePresence()

    /// Taranan aygıtlardan (aile, dahili mi) sayım; fare sayısı köprünün başlattığı fare sayısıdır
    /// (negatif = framework yüklenemedi → 0).
    public init(startedMice: Int, devices: [(familyID: Int, isBuiltIn: Bool)]) {
        let trackpads = devices.filter { MultitouchFamily.kind(familyID: $0.familyID, isBuiltIn: $0.isBuiltIn) == .trackpad }
        // MacBook'ta tek trackpad birden çok dahili çoklu dokunma aygıtı olarak görünebilir
        // (ör. aile 176 ve 113); dahililer tek trackpad sayılır, harici olanlar tek tek sayılır.
        let builtIn = trackpads.contains { $0.isBuiltIn }
        let external = trackpads.filter { !$0.isBuiltIn }.count
        self.init(mice: max(startedMice, 0), trackpads: (builtIn ? 1 : 0) + external,
                  builtInTrackpad: builtIn)
    }

    public func isPresent(_ kind: InputDeviceKind) -> Bool {
        switch kind {
        case .magicMouse: return mice > 0
        case .trackpad: return trackpads > 0
        }
    }
}

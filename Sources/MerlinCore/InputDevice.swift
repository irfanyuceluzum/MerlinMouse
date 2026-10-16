import Foundation

/// Atamanın ait olduğu dokunma aygıtı. Bugün yalnız Magic Mouse işlenir; trackpad altyapısı hazırdır.
public enum InputDeviceKind: String, Codable, CaseIterable, Hashable {
    case magicMouse, trackpad

    /// Arayüzde gösterilen ad.
    public var displayName: String {
        switch self {
        case .magicMouse: return MerlinText.t("Magic Mouse")
        case .trackpad: return MerlinText.t("Trackpad")
        }
    }
}

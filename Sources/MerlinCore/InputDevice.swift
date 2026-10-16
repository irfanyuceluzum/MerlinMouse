import Foundation

/// Atamanın ait olduğu dokunma aygıtı. Trackpad'de 3–4 parmakla dokunma, basma ve çift dokunma işlenir.
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

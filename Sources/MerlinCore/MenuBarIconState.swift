import Foundation

/// Menü çubuğu simgesinin durumu; saf mantık, arayüzden bağımsız.
public enum MenuBarIconState: Equatable {
    case normal, disabled, paused, noPermission, lowBattery, criticalBattery

    /// Öncelik: disabled > paused > noPermission > criticalBattery (≤10) > lowBattery (≤20) > normal.
    public static func resolve(enabled: Bool, paused: Bool, trusted: Bool, batteryPercent: Int?) -> MenuBarIconState {
        if !enabled { return .disabled }
        if paused { return .paused }
        if !trusted { return .noPermission }
        if let p = batteryPercent {
            if p <= 10 { return .criticalBattery }
            if p <= 20 { return .lowBattery }
        }
        return .normal
    }

    /// SF Symbol adı.
    public var symbolName: String {
        switch self {
        case .normal, .disabled: return "magicmouse"
        case .paused: return "pause.circle"
        case .noPermission: return "exclamationmark.triangle"
        case .lowBattery: return "battery.25"
        case .criticalBattery: return "battery.0"
        }
    }

    /// Simgenin üzerine gelince görünen kısa açıklama.
    public var help: String {
        switch self {
        case .normal: return MerlinText.t("Merlin Mouse çalışıyor")
        case .disabled: return MerlinText.t("Merlin Mouse kapalı")
        case .paused: return MerlinText.t("Merlin Mouse duraklatıldı")
        case .noPermission: return MerlinText.t("Erişilebilirlik izni gerekli")
        case .lowBattery: return MerlinText.t("Magic Mouse pili azaldı")
        case .criticalBattery: return MerlinText.t("Magic Mouse pili kritik")
        }
    }
}

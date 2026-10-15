import Foundation

/// Atama satırındaki durum rozetinin türü.
public enum BindingStatusKind: Equatable {
    case free, macOS, btt, caution, blocked, disabled, shadows, replacesDisabled
}

public enum BindingStatus {
    /// Kapalı → disabled; engelleyici çakışma → blocked; sonra macOS > btt > shadows > caution; yoksa free.
    public static func kind(enabled: Bool, conflicts: [Conflict]) -> BindingStatusKind {
        if !enabled { return .disabled }
        if conflicts.contains(where: { $0.level.blocksSave }) { return .blocked }
        let levels = Set(conflicts.map { $0.level })
        if levels.contains(.macOS) { return .macOS }
        if levels.contains(.btt) { return .btt }
        if levels.contains(.shadows) { return .shadows }
        if levels.contains(.caution) { return .caution }
        if levels.contains(.replacesDisabled) { return .replacesDisabled }
        return .free
    }
}
